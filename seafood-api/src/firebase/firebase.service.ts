import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';

/**
 * Wraps the Firebase Admin SDK. The service account is loaded from the file at
 * GOOGLE_APPLICATION_CREDENTIALS (see .env). This works from any Node process —
 * it does NOT require the Firebase Blaze plan. Firestore + FCM usage counts
 * against the free Spark quota.
 */
@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);

  onModuleInit() {
    if (admin.apps.length === 0) {
      // applicationDefault() reads GOOGLE_APPLICATION_CREDENTIALS.
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      this.logger.log('Firebase Admin initialized');
    }
  }

  get firestore(): admin.firestore.Firestore {
    return admin.firestore();
  }

  get messaging(): admin.messaging.Messaging {
    return admin.messaging();
  }

  /** Verify a Firebase Auth ID token minted by the Flutter app. */
  verifyIdToken(idToken: string): Promise<admin.auth.DecodedIdToken> {
    return admin.auth().verifyIdToken(idToken);
  }
}
