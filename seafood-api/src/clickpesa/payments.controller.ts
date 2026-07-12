import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  InternalServerErrorException,
  Logger,
  NotFoundException,
  Post,
  PreconditionFailedException,
  Req,
  ServiceUnavailableException,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { FirebaseService } from '../firebase/firebase.service';
import { ClickPesaService } from './clickpesa.service';

interface OrderBody {
  orderId?: string;
}

@Controller('payments')
@UseGuards(FirebaseAuthGuard)
export class PaymentsController {
  private readonly logger = new Logger(PaymentsController.name);

  constructor(
    private readonly firebase: FirebaseService,
    private readonly clickpesa: ClickPesaService,
  ) {}

  /**
   * Pay-In. Generates a ClickPesa hosted-checkout link for the caller's order.
   * Replaces the `createClickPesaPayment` Cloud Function.
   */
  @Post('create')
  async create(@Req() req: Request & { uid: string }, @Body() body: OrderBody) {
    const { orderId } = body;
    if (!orderId) throw new BadRequestException('Missing orderId');

    const orderRef = this.firebase.firestore.collection('orders').doc(orderId);
    const snap = await orderRef.get();
    if (!snap.exists) throw new NotFoundException('Order not found');

    const order = snap.data()!;
    if (order.customerId !== req.uid) throw new ForbiddenException('Not your order');

    let paymentUrl: string;
    try {
      paymentUrl = await this.clickpesa.createCheckoutLink({
        orderId,
        totalPrice: order.grandTotal,
        customerName: order.customerName,
        customerPhone: order.phoneNumber,
      });
    } catch (err: any) {
      this.logger.error(
        `ClickPesa checkout-link error: ${JSON.stringify(err.response?.data || err.message)}`,
      );
      throw new ServiceUnavailableException(
        'Could not reach the payment provider. Please try again.',
      );
    }

    // Only awaiting payment — the order moves to escrow when the webhook confirms.
    await orderRef.update({ paymentMethod: 'clickpesa', paymentStatus: 'pending' });

    return { success: true, paymentUrl };
  }

  /**
   * Pay-Out. Releases escrow to seller + driver, but only marks the order
   * released if every required payout succeeds. Replaces `releaseEscrow`.
   */
  @Post('release')
  async release(@Req() req: Request & { uid: string }, @Body() body: OrderBody) {
    const { orderId } = body;
    if (!orderId) throw new BadRequestException('Missing orderId');

    const orderRef = this.firebase.firestore.collection('orders').doc(orderId);
    const snap = await orderRef.get();
    if (!snap.exists) throw new NotFoundException('Order not found');

    const order = snap.data()!;
    if (order.customerId !== req.uid) throw new ForbiddenException('Not your order');
    if (order.paymentStatus !== 'held_in_escrow') {
      throw new PreconditionFailedException('Payment is not in escrow');
    }

    const productTotal = order.total || 0;
    const deliveryFee = order.delivery?.cost || 0;
    const sellerId = order.items?.[0]?.sellerId; // one seller per order (see plan open item)
    const driverId = order.delivery?.driverId;

    try {
      await this.payParty(orderId, sellerId, productTotal, 'seller');
      await this.payParty(orderId, driverId, deliveryFee, 'driver');
    } catch (err: any) {
      // Leave funds in escrow so nothing is lost; customer/support can retry.
      this.logger.error(
        `Error releasing escrow for ${orderId}: ${JSON.stringify(err.response?.data || err.message)}`,
      );
      if (err instanceof PreconditionFailedException) throw err;
      throw new InternalServerErrorException(
        'Failed to release funds via ClickPesa. Funds remain in escrow.',
      );
    }

    await orderRef.update({
      paymentStatus: 'released',
      status: 'delivered',
      customerConfirmedReceipt: true,
    });

    return { success: true };
  }

  /**
   * Pay one party their share. No-op if nothing is owed. Throws if the recipient
   * has no mobile-money number on file, so we never silently skip paying someone.
   */
  private async payParty(
    orderId: string,
    userId: string | undefined,
    amount: number,
    suffix: 'seller' | 'driver',
  ): Promise<void> {
    if (!userId || amount <= 0) return;

    const userSnap = await this.firebase.firestore.collection('users').doc(userId).get();
    const data = userSnap.data() || {};
    const phone: string | undefined =
      data.payoutDetails?.accountNumber || data.mobilePayment || data.phone;

    if (!phone) {
      throw new PreconditionFailedException(
        `Recipient (${suffix}) has no mobile-money number on file.`,
      );
    }

    const result = await this.clickpesa.createMobileMoneyPayout({
      // ClickPesa requires alphanumeric-only references (no `_` or `-`), so we
      // append the party as a bare suffix, e.g. "<orderId>seller".
      orderReference: `${orderId}${suffix}`,
      amount,
      phoneNumber: phone,
    });
    this.logger.log(
      `Payout to ${suffix} (${userId}) accepted for TZS ${amount}: ${result?.id || result?.status || 'OK'}`,
    );
  }
}
