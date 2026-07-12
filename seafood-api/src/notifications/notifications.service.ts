import { Injectable, Logger } from '@nestjs/common';
import { FirebaseService } from '../firebase/firebase.service';

/**
 * Sends FCM push notifications. Port of the `sendPush` / `getToken` helpers from
 * the old Cloud Function. NOTE: this service sends the push ONLY — the Flutter
 * app already writes the in-app "bell" documents to the `notifications`
 * collection, so we must not write them again (that would double the bell).
 */
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly firebase: FirebaseService) {}

  /** Look up a user's FCM device token. */
  async getToken(uid?: string): Promise<string | null> {
    if (!uid) return null;
    try {
      const snap = await this.firebase.firestore.collection('users').doc(uid).get();
      return snap.exists ? snap.data()?.fcmToken || null : null;
    } catch (e: any) {
      this.logger.error(`getToken(${uid}) error: ${e.message}`);
      return null;
    }
  }

  /** Send a push to a specific user by uid. Safe no-op if they have no token. */
  async pushToUser(
    uid: string | undefined,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    const token = await this.getToken(uid);
    if (!token) {
      this.logger.debug(`pushToUser: no token for ${uid}, skipping`);
      return;
    }

    const message = {
      token,
      notification: { title, body },
      android: {
        priority: 'high' as const,
        notification: {
          channelId: 'zanseafood_orders',
          sound: 'default',
          priority: 'high' as const,
          defaultVibrateTimings: true,
          visibility: 'public' as const,
        },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } },
      },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    };

    try {
      const result = await this.firebase.messaging.send(message);
      this.logger.log(`Push sent: ${result}`);
    } catch (err: any) {
      // Token may be stale — log but don't crash the listener.
      this.logger.error(`Push failed: ${err.code} ${err.message}`);
    }
  }
}
