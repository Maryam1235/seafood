import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  NotFoundException,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { FirebaseService } from '../firebase/firebase.service';
import { RecommendationsService } from './recommendations.service';

interface RecordPurchaseBody {
  orderId?: string;
}

/**
 * Authenticated endpoints for the recommendation pipeline.
 * Used when an order is confirmed without going through ClickPesa
 * (e.g. customer pickup), so purchase_history still gets written.
 */
@Controller('recommendations')
@UseGuards(FirebaseAuthGuard)
export class RecommendationsController {
  constructor(
    private readonly firebase: FirebaseService,
    private readonly recommendations: RecommendationsService,
  ) {}

  /**
   * Record purchase_history for a confirmed order owned by the caller,
   * then notify the Python recommendation service (if configured).
   */
  @Post('record-purchase')
  async recordPurchase(
    @Req() req: Request & { uid: string },
    @Body() body: RecordPurchaseBody,
  ) {
    const { orderId } = body;
    if (!orderId) throw new BadRequestException('Missing orderId');

    const orderRef = this.firebase.firestore.collection('orders').doc(orderId);
    const snap = await orderRef.get();
    if (!snap.exists) throw new NotFoundException('Order not found');

    const order = snap.data()!;
    if (order.customerId !== req.uid) {
      throw new ForbiddenException('Not your order');
    }

    const status = String(order.status || '').toLowerCase();
    const paymentStatus = String(order.paymentStatus || '').toLowerCase();
    const fulfillment = String(order.fulfillment || '').toLowerCase();
    const allowedStatus = ['confirmed', 'delivered', 'completed'].includes(status);
    const allowedPayment = ['held_in_escrow', 'released', 'paid'].includes(paymentStatus);
    const isPickup = fulfillment === 'pickup';

    if (!allowedStatus && !allowedPayment && !isPickup) {
      throw new BadRequestException(
        'Order is not confirmed yet; cannot record purchase history.',
      );
    }

    await this.recommendations.recordPurchaseHistory(orderId, order);
    return { success: true, orderId };
  }
}
