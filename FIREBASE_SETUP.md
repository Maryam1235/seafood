# Firebase Setup Instructions

> **Server logic moved off Cloud Functions.** ClickPesa payments and push-notification
> sending are no longer in `functions/` (which needed the paid Blaze plan). They now run
> in the self-hosted NestJS server at **`seafood-api/`** — see `seafood-api/README.md`.
> Firestore, Auth, and FCM remain on the free Spark plan. The `functions/` folder is
> retained for history but is no longer deployed.

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name (e.g., "auth-app")
4. Disable Google Analytics (optional)
5. Click "Create project"

## Step 2: Enable Authentication

1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Click "Sign-in method" tab
4. Enable "Email/Password"
5. Click "Save"

## Step 3: Create Firestore Database

1. Go to "Firestore Database"
2. Click "Create database"
3. Select "Start in test mode"
4. Choose a location
5. Click "Enable"

## Step 4: Add Flutter App to Firebase

### For Android:
1. Click the Android icon in Firebase Console
2. Enter package name: `com.example.app`
3. Download `google-services.json`
4. Place it in: `app/android/app/google-services.json`
5. Add to `android/build.gradle`:
   ```gradle
   dependencies {
       classpath 'com.google.gms:google-services:4.4.0'
   }
   ```
6. Add to `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

### For iOS (if needed):
1. Click the iOS icon
2. Enter bundle ID: `com.example.app`
3. Download `GoogleService-Info.plist`
4. Add to `app/ios/Runner/`

## Step 5: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This will generate `lib/firebase_options.dart` automatically.

## Step 6: Run the App

```bash
cd app
flutter pub get
flutter run
```

## Firestore Security Rules (Optional - for production)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
