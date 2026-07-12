import { Body, Controller, Logger, Post, Res } from '@nestjs/common';
import { Response } from 'express';
import { FirebaseService } from '../firebase/firebase.service';
import { ClickPesaService } from './clickpesa.service';
import { RecommendationsService } from '../recommendations/recommendations.service';

/**
 * Receives ClickPesa webhooks. NOT behind the auth guard — it is called by
 * ClickPesa, not the app.
 *
 * ClickPesa webhooks carry NO auth header (the dashboard only lets you set an
 * event + URL). So we never trust the webhook body. We treat it purely as a
 * "something changed" trigger, then re-query ClickPesa's authenticated API for
 * the REAL status before moving any money. A spoofed webhook cannot fake
 * ClickPesa's own API response.
 *
 * Payload envelope:  { event: "PAYMENT RECEIVED", data: { status, orderReference, id, ... } }
 */
@Controller('webhooks')
export class WebhooksController {
  private readonly logger = new Logger(WebhooksController.name);

  constructor(
    private readonly firebase: FirebaseService,
    private readonly clickpesa: ClickPesaService,
    private readonly recommendations: RecommendationsService,
  ) {}

  @Post('clickpesa')
  async handleClickPesa(@Body() body: any, @Res() res: Response) {
    const event: string = body?.event || '';
    const data = body?.data || {};
    const orderReference: string | undefined = data.orderReference || body?.orderReference;

    if (!orderReference) return res.status(400).send('No order reference provided');

    // Defense-in-depth: if the webhook carries a checksum, verify it. We only
    // log a mismatch (the authoritative re-query below is the real gate), so a
    // canonicalization edge case never blocks a legitimate payment.
    if (!this.clickpesa.verifyChecksum(body)) {
      this.logger.warn(`Webhook checksum mismatch for ${orderReference} — verifying via API anyway`);
    }

    // PAYOUT events (INITIATED / REFUNDED / REVERSED) reference our payout ids
    // (e.g. "<orderId>_seller"). We log them; escrow release is driven by the
    // /payments/release call, not by these.
    if (event.toUpperCase().startsWith('PAYOUT')) {
      this.logger.log(`Payout webhook "${event}" for ${orderReference}: ${data.status}`);
      return res.status(200).send('OK');
    }

    // PAYMENT events → verify the truth with ClickPesa before touching Firestore.
    const orderRef = this.firebase.firestore.collection('orders').doc(orderReference);
    const snap = await orderRef.get();
    if (!snap.exists) {
      this.logger.warn(`clickPesaWebhook: order ${orderReference} not found`);
      return res.status(404).send('Order not found');
    }

    let authoritativeStatus: string;
    try {
      const record = await this.clickpesa.queryPaymentStatus(orderReference);
      authoritativeStatus = String(record?.status || '').toUpperCase();
      this.logger.log(
        `Webhook "${event}" for ${orderReference}; ClickPesa reports status=${authoritativeStatus}`,
      );
    } catch (err: any) {
      this.logger.error(
        `Could not verify payment ${orderReference}: ${JSON.stringify(err.response?.data || err.message)}`,
      );
      // 502 so ClickPesa retries later rather than us acting on unverified data.
      return res.status(502).send('Could not verify payment');
    }

    try {
      if (authoritativeStatus === 'SUCCESS' || authoritativeStatus === 'SETTLED') {
        const current = snap.data()!.paymentStatus;
        // Idempotent: don't reprocess an order already in/through escrow.
        if (current !== 'held_in_escrow' && current !== 'released') {
          const order = snap.data()!;
          await orderRef.update({
            paymentStatus: 'held_in_escrow',
            status: 'confirmed', // confirm so seller/driver can proceed
            clickPesaPayInRef: data.id || null,
          });
          await this.recommendations.recordPurchaseHistory(orderReference, order);
        }
      } else if (['FAILED', 'REVERSED', 'REFUNDED'].includes(authoritativeStatus)) {
        await orderRef.update({ paymentStatus: 'failed' });
      }
      // PENDING / PROCESSING / ON-HOLD → do nothing yet; a later webhook will fire.

      return res.status(200).send('OK');
    } catch (error: any) {
      this.logger.error(`Webhook processing error: ${error.message}`);
      return res.status(500).send('Internal Server Error');
    }
  }
}
