import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import * as crypto from 'crypto';

const CLICKPESA_API_URL = 'https://api.clickpesa.com/third-parties';

/**
 * Canonicalize for checksum: recursively sort object keys alphabetically at
 * every nesting level (arrays keep order, elements recursed). Matches the
 * reference implementation in ClickPesa's checksum docs exactly.
 */
function canonicalize(obj: any): any {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(canonicalize);
  return Object.keys(obj)
    .sort()
    .reduce((acc: Record<string, any>, key) => {
      acc[key] = canonicalize(obj[key]);
      return acc;
    }, {});
}

function normalizePhoneNumber(phoneNumber: string): string {
  const compact = phoneNumber.replace(/[\s-]/g, '').replace(/^\+/, '');
  if (/^0[67]\d+$/.test(compact)) return `255${compact.slice(1)}`;
  if (/^[67]\d+$/.test(compact)) return `255${compact}`;
  return compact;
}

/**
 * ClickPesa integration. Ports the hardened logic from the old Cloud Function:
 *   - real auth: exchange client-id + api-key for a short-lived JWT (cached ~55m)
 *   - checkout link generation (pay-in)
 *   - mobile-money payout (pay-out)
 * Docs: https://docs.clickpesa.com/api-reference
 */
@Injectable()
export class ClickPesaService {
  private readonly logger = new Logger(ClickPesaService.name);
  private cachedToken: { value: string; expiresAt: number } | null = null;

  constructor(private readonly config: ConfigService) {}

  /**
   * HMAC-SHA256 of the canonicalized, compact-JSON payload, hex-encoded.
   * Uses the checksum key from the ClickPesa dashboard (CLICKPESA_CHECKSUM_SECURITY).
   */
  private computeChecksum(payload: Record<string, any>): string {
    const key = this.config.getOrThrow<string>('CLICKPESA_CHECKSUM_SECURITY');
    const payloadString = JSON.stringify(canonicalize(payload));
    return crypto.createHmac('sha256', key).update(payloadString).digest('hex');
  }

  /** Attach the `checksum` field to an outgoing request payload (if checksum
   *  security is configured). Returns the payload unchanged when no key is set. */
  private withChecksum<T extends Record<string, any>>(payload: T): T & { checksum?: string } {
    if (!this.config.get<string>('CLICKPESA_CHECKSUM_SECURITY')) return payload;
    return { ...payload, checksum: this.computeChecksum(payload) };
  }

  /**
   * Verify a checksum received on an inbound webhook. Recomputes over the whole
   * payload minus the `checksum`/`checksumMethod` fields (per the docs) and
   * compares. Returns true if no checksum was sent (nothing to verify).
   */
  verifyChecksum(payload: Record<string, any>): boolean {
    const received = payload?.checksum;
    if (!received) return true; // nothing to verify
    const { checksum, checksumMethod, ...rest } = payload;
    return this.computeChecksum(rest) === received;
  }

  /**
   * POST /generate-token with `client-id` + `api-key` headers → JWT (valid ~1h).
   * Cached in memory for 55 min to stay safely inside the window.
   * https://docs.clickpesa.com/api-reference/authorization/generate-token
   */
  private async getToken(): Promise<string> {
    const now = Date.now();
    if (this.cachedToken && this.cachedToken.expiresAt > now) {
      return this.cachedToken.value;
    }

    const res = await axios.post(
      `${CLICKPESA_API_URL}/generate-token`,
      {},
      {
        headers: {
          'client-id': this.config.getOrThrow<string>('CLICKPESA_CLIENT_ID'),
          'api-key': this.config.getOrThrow<string>('CLICKPESA_API_KEY'),
        },
      },
    );

    const token = res.data?.token;
    if (!res.data?.success || !token) {
      throw new Error(`ClickPesa token generation failed: ${JSON.stringify(res.data)}`);
    }

    this.cachedToken = { value: token, expiresAt: now + 55 * 60 * 1000 };
    return token;
  }

  private async authHeaders() {
    const token = await this.getToken();
    // ClickPesa returns the token already prefixed with "Bearer ", so don't
    // double it up — normalize either form to a single Bearer header.
    const authorization = token.startsWith('Bearer ') ? token : `Bearer ${token}`;
    return {
      Authorization: authorization,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    };
  }

  /**
   * Generate a hosted-checkout link (pay-in).
   * https://docs.clickpesa.com/api-reference/collection/generate-checkout-link
   * Returns the `checkoutLink` URL.
   */
  async createCheckoutLink(params: {
    orderId: string;
    totalPrice: number;
    customerName?: string;
    customerPhone?: string;
  }): Promise<string> {
    const payload: Record<string, string> = {
      totalPrice: String(params.totalPrice), // ClickPesa expects string for checkout
      orderReference: params.orderId,
      orderCurrency: 'TZS',
      description: `ZanSeaFood Order ${params.orderId}`,
      customerName: params.customerName || 'ZanSeaFood Customer',
    };
    if (params.customerPhone) {
      payload.customerPhone = params.customerPhone.replace('+', '');
    }

    const headers = await this.authHeaders();
    const response = await axios.post(
      `${CLICKPESA_API_URL}/checkout-link/generate-checkout-url`,
      this.withChecksum(payload),
      { headers },
    );

    const link = response.data?.checkoutLink;
    if (!link) {
      throw new Error(`No checkoutLink in ClickPesa response: ${JSON.stringify(response.data)}`);
    }
    return link;
  }

  /**
   * Create a mobile-money payout (pay-out / disbursement).
   * https://docs.clickpesa.com/api-reference/disbursement/mno-payout/create-mno-payout
   * Throws on API error so callers can decide whether to keep funds in escrow.
   */
  async createMobileMoneyPayout(params: {
    orderReference: string;
    amount: number;
    phoneNumber: string;
  }): Promise<any> {
    const payload = {
      amount: Number(params.amount), // ClickPesa expects a number for payouts
      orderReference: params.orderReference,
      phoneNumber: normalizePhoneNumber(params.phoneNumber),
      currency: 'TZS',
    };

    const headers = await this.authHeaders();
    const response = await axios.post(
      `${CLICKPESA_API_URL}/payouts/create-mobile-money-payout`,
      this.withChecksum(payload),
      { headers },
    );
    return response.data;
  }

  /**
   * Authoritative payment-status lookup by order reference. Used to verify
   * webhooks: never trust the webhook body, re-query ClickPesa directly.
   * GET https://api.clickpesa.com/third-parties/payments/{orderReference}
   * Returns an object with a `status` field (SUCCESS, SETTLED, PENDING,
   * PROCESSING, FAILED, ON-HOLD, REFUNDED, REVERSED). Some responses come back
   * as an array of matching payments — this normalizes to a single record.
   */
  async queryPaymentStatus(orderReference: string): Promise<any> {
    const headers = await this.authHeaders();
    const response = await axios.get(
      `${CLICKPESA_API_URL}/payments/${encodeURIComponent(orderReference)}`,
      { headers },
    );
    const data = response.data;
    return Array.isArray(data) ? data[0] : data;
  }
}
