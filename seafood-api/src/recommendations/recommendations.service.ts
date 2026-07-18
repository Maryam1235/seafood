import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import * as admin from 'firebase-admin';
import { FirebaseService } from '../firebase/firebase.service';

@Injectable()
export class RecommendationsService {
  private readonly logger = new Logger(RecommendationsService.name);

  constructor(
    private readonly firebase: FirebaseService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Writes one purchase_history doc per order line item, then notifies the
   * Python recommendation service so training can be scheduled.
   * Safe to call more than once for the same order (merge + stable doc ids).
   */
  async recordPurchaseHistory(orderId: string, order: admin.firestore.DocumentData) {
    const items = Array.isArray(order.items) ? order.items : [];
    if (!order.customerId || items.length === 0) {
      this.logger.warn(
        `Skip purchase_history for ${orderId}: missing customerId or items`,
      );
      return;
    }

    const batch = this.firebase.firestore.batch();
    let written = 0;

    for (const item of items) {
      const productId = item.productId || item.id;
      if (!productId) continue;

      const productSnap = await this.firebase.firestore
        .collection('products')
        .doc(String(productId))
        .get();
      const product = productSnap.data() || {};
      const ref = this.firebase.firestore
        .collection('purchase_history')
        .doc(`${orderId}_${productId}`);

      batch.set(
        ref,
        {
          userId: order.customerId,
          productId: String(productId),
          quantity: Number(item.quantity || 1),
          price: Number(item.price || product.price || 0),
          category: item.category || product.category || null,
          purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
          orderId,
        },
        { merge: true },
      );
      written += 1;
    }

    if (written === 0) {
      this.logger.warn(`Skip purchase_history for ${orderId}: no valid product lines`);
      return;
    }

    await batch.commit();
    this.logger.log(`Purchase history recorded for order ${orderId} (${written} items)`);
    await this.notifyRecommendationService(orderId);
  }

  private async notifyRecommendationService(orderId: string) {
    const baseUrl = this.config.get<string>('RECOMMENDATION_SERVICE_URL');
    if (!baseUrl) {
      this.logger.debug(
        'RECOMMENDATION_SERVICE_URL not set; skipping recommendation train notify',
      );
      return;
    }

    try {
      await axios.post(
        `${baseUrl.replace(/\/$/, '')}/events/purchase`,
        { orderId },
        { timeout: 3000 },
      );
      this.logger.log(`Notified recommendation service for order ${orderId}`);
    } catch (error: any) {
      this.logger.warn(
        `Recommendation service notification failed for ${orderId}: ${error.message}`,
      );
    }
  }
}
