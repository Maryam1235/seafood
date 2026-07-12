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

  async recordPurchaseHistory(orderId: string, order: admin.firestore.DocumentData) {
    const items = Array.isArray(order.items) ? order.items : [];
    if (!order.customerId || items.length === 0) return;

    const batch = this.firebase.firestore.batch();
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
    }

    await batch.commit();
    this.logger.log(`Purchase history recorded for order ${orderId}`);
    await this.notifyRecommendationService(orderId);
  }

  private async notifyRecommendationService(orderId: string) {
    const baseUrl = this.config.get<string>('RECOMMENDATION_SERVICE_URL');
    if (!baseUrl) return;

    try {
      await axios.post(
        `${baseUrl.replace(/\/$/, '')}/events/purchase`,
        { orderId },
        { timeout: 3000 },
      );
    } catch (error: any) {
      this.logger.warn(
        `Recommendation service notification failed for ${orderId}: ${error.message}`,
      );
    }
  }
}
