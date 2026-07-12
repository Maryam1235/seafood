import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { FirebaseService } from '../firebase/firebase.service';
import { NotificationsService } from './notifications.service';

/**
 * Replaces the Firestore-trigger Cloud Functions (`onNewOrder`, `onOrderUpdated`).
 * Attaches a real-time listener on the `orders` collection and sends the FCM
 * push for the same events. PUSH ONLY — the app writes the in-app bell docs.
 *
 * Before/after semantics: Firestore's onSnapshot gives only the current doc, so
 * we keep an in-memory baseline (last-seen status/driver per order) to detect
 * transitions. The FIRST snapshot after startup just seeds this baseline and
 * sends nothing — this prevents re-notifying every existing order on restart.
 * (Trade-off: an event that lands while the server is down is not pushed; the
 * app still wrote the bell doc, so it is not lost in-app.)
 */
@Injectable()
export class OrderListenerService implements OnModuleInit {
  private readonly logger = new Logger(OrderListenerService.name);

  private initialized = false;
  private readonly seenStatus = new Map<string, string>();
  private readonly seenDriver = new Map<string, string>();
  private readonly knownOrders = new Set<string>();

  constructor(
    private readonly firebase: FirebaseService,
    private readonly notifications: NotificationsService,
  ) {}

  onModuleInit() {
    this.firebase.firestore.collection('orders').onSnapshot(
      (snapshot) => {
        if (!this.initialized) {
          // Seed the baseline from existing orders; send nothing.
          snapshot.forEach((doc) => this.seed(doc.id, doc.data()));
          this.initialized = true;
          this.logger.log(`Order listener attached (${snapshot.size} existing orders seeded)`);
          return;
        }
        for (const change of snapshot.docChanges()) {
          this.handleChange(change.type, change.doc.id, change.doc.data()).catch((e) =>
            this.logger.error(`handleChange(${change.doc.id}) error: ${e.message}`),
          );
        }
      },
      (err) => this.logger.error(`Order listener error: ${err.message}`),
    );
  }

  private seed(orderId: string, order: FirebaseFirestore.DocumentData) {
    this.knownOrders.add(orderId);
    if (order.status) this.seenStatus.set(orderId, order.status);
    const driverId = order.delivery?.driverId;
    if (driverId) this.seenDriver.set(orderId, driverId);
  }

  private async handleChange(
    type: 'added' | 'modified' | 'removed',
    orderId: string,
    order: FirebaseFirestore.DocumentData,
  ) {
    if (type === 'removed') return;

    // ── New order → notify each seller ──────────────────────────────────────
    if (type === 'added' && !this.knownOrders.has(orderId)) {
      await this.notifyNewOrder(orderId, order);
      this.seed(orderId, order); // record baseline for future transitions
      return;
    }

    // ── Status transitions → notify customer ────────────────────────────────
    const prevStatus = this.seenStatus.get(orderId);
    const newStatus = order.status;
    if (newStatus && newStatus !== prevStatus) {
      await this.notifyStatusTransition(orderId, order, prevStatus, newStatus);
      this.seenStatus.set(orderId, newStatus);
    }

    // ── Driver newly assigned → notify driver ───────────────────────────────
    const prevDriver = this.seenDriver.get(orderId);
    const newDriver = order.delivery?.driverId;
    if (newDriver && !prevDriver) {
      await this.notifyDriverAssigned(orderId, order, newDriver);
      this.seenDriver.set(orderId, newDriver);
    }
  }

  private async notifyNewOrder(orderId: string, order: FirebaseFirestore.DocumentData) {
    const items = order.items || [];
    const sellerIds = [...new Set(items.map((i: any) => i.sellerId).filter(Boolean))] as string[];
    if (sellerIds.length === 0) return;

    const customerName = await this.displayName(order.customerId, 'A customer');

    await Promise.all(
      sellerIds.map(async (sellerId) => {
        const sellerItems = items.filter((i: any) => i.sellerId === sellerId);
        const subtotal = sellerItems.reduce(
          (sum: number, i: any) => sum + (i.price || 0) * (i.quantity || 1),
          0,
        );
        const count = sellerItems.length;
        await this.notifications.pushToUser(
          sellerId,
          'New Order Received 🛒',
          `${customerName} ordered ${count} item${count > 1 ? 's' : ''} — TShs ${subtotal.toFixed(0)}`,
          { orderId, type: 'new_order', customerName },
        );
      }),
    );
  }

  private async notifyStatusTransition(
    orderId: string,
    order: FirebaseFirestore.DocumentData,
    prevStatus: string | undefined,
    newStatus: string,
  ) {
    const customerId = order.customerId;

    if (prevStatus === 'pending' && newStatus === 'confirmed') {
      await this.notifications.pushToUser(
        customerId,
        'Order Confirmed ✅',
        'Your order has been confirmed by the seller. Please choose how you want to receive it.',
        { orderId, type: 'order_status', status: 'confirmed' },
      );
    } else if (prevStatus !== 'cancelled' && newStatus === 'cancelled') {
      const items = order.items || [];
      const firstSeller = items.map((i: any) => i.sellerId).filter(Boolean)[0];
      const sellerName = await this.displayName(firstSeller, 'the seller');
      await this.notifications.pushToUser(
        customerId,
        'Order Cancelled ❌',
        `Sorry, your order was cancelled by ${sellerName}.`,
        { orderId, type: 'order_status', status: 'cancelled' },
      );
    } else if (prevStatus !== 'delivered' && newStatus === 'delivered') {
      await this.notifications.pushToUser(
        customerId,
        'Order Delivered 🎉',
        'Your seafood order has been delivered. Enjoy your meal!',
        { orderId, type: 'order_status', status: 'delivered' },
      );
    }
  }

  private async notifyDriverAssigned(
    orderId: string,
    order: FirebaseFirestore.DocumentData,
    driverId: string,
  ) {
    const customerName = await this.displayName(order.customerId, 'A customer');
    const deliveryCost = order.delivery?.cost || 0;
    const vehicleType = order.delivery?.vehicleType || '';
    await this.notifications.pushToUser(
      driverId,
      'New Delivery Request 🚀',
      `New delivery from ${customerName}. Delivery fee: TShs ${deliveryCost}`,
      { orderId, type: 'new_delivery', vehicleType, customerName },
    );
  }

  /** Resolve a user's display name, with a fallback. */
  private async displayName(uid: string | undefined, fallback: string): Promise<string> {
    if (!uid) return fallback;
    try {
      const snap = await this.firebase.firestore.collection('users').doc(uid).get();
      if (!snap.exists) return fallback;
      const d = snap.data()!;
      return d.fullName || d.username || fallback;
    } catch {
      return fallback;
    }
  }
}
