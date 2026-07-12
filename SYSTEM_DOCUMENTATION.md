# ZanSeaFood — Full System Documentation

> A complete guide to understanding how the app works, how it connects to the database,
> how users are managed, and the full flow from login to delivery completion.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Project Structure](#2-project-structure)
3. [Firebase — The Database & Backend](#3-firebase--the-database--backend)
4. [Firestore Collections (Database Schema)](#4-firestore-collections-database-schema)
5. [User Roles](#5-user-roles)
6. [Complete System Flow](#6-complete-system-flow)
7. [Flutter App — Screen by Screen](#7-flutter-app--screen-by-screen)
8. [Admin Panel — Feature by Feature](#8-admin-panel--feature-by-feature)
9. [Notifications System](#9-notifications-system)
10. [Location System](#10-location-system)
11. [Image Uploads](#11-image-uploads)
12. [State Management](#12-state-management)
13. [Bilingual Support](#13-bilingual-support)
14. [Key Files Reference](#14-key-files-reference)

---

## 1. System Overview

ZanSeaFood is a **seafood marketplace app** built for Tanzania (Zanzibar).
It is organized as a monorepo with separate deployable parts:

| Part | Technology | Purpose |
|------|-----------|---------|
| **Mobile App** | Flutter (Dart) | Used by Customers, Sellers, and Drivers |
| **Admin Panel** | React + Vite (JavaScript) | Used by the Administrator to manage everything |
| **API** | NestJS (Node.js) | Handles ClickPesa payments, FCM notifications, and backend workflows |
| **Recommendation Service** | FastAPI (Python) | Trains product recommendations from purchase history |

All runtime parts use the **same Firebase project** (`testing-bc269`), so data is shared in real time.

---

## 2. Project Structure

```
seafood/
├── app/                        ← Flutter mobile app
│   └── lib/
│       ├── main.dart           ← App entry point
│       ├── firebase_options.dart ← Firebase connection config
│       ├── providers/
│       │   └── language_provider.dart  ← English/Swahili switching
│       ├── services/
│       │   ├── auth_service.dart       ← Login, register, logout
│       │   ├── cart_service.dart       ← Cart & order placement
│       │   ├── location_service.dart   ← GPS & reverse geocoding
│       │   └── notification_service.dart ← FCM push notifications
│       └── screens/
│           ├── splash_screen.dart
│           ├── language_screen.dart
│           ├── login_screen.dart
│           ├── register_screen.dart
│           ├── customer_dashboard.dart
│           ├── seller_dashboard.dart
│           ├── driver_dashboard.dart
│           └── ... (26 screens total)
│
├── react_admin/                ← React admin panel
│   └── src/
│       ├── firebase.js         ← Firebase connection config
│       ├── pages/
│       │   └── Dashboard.jsx   ← Main layout
│       └── components/
│           ├── Overview.jsx    ← Stats dashboard
│           ├── UsersTable.jsx  ← User management
│           ├── ProductsTable.jsx
│           ├── OrdersTable.jsx
│           ├── DeliveryManagement.jsx
│           ├── Reports.jsx     ← Analytics & charts
│           └── Settings.jsx
├── seafood-api/                ← NestJS backend API
└── recommendation-service/     ← Python FastAPI recommendation engine
```

---

## 3. Firebase — The Database & Backend

### What is Firebase?
Firebase is Google's cloud platform. It acts as the **database, authentication system,
file storage, and push notification service** — all in one.

### Firebase Project
- **Project ID:** `testing-bc269`
- **Console:** https://console.firebase.google.com/project/testing-bc269

### Services Used

| Service | What it does |
|---------|-------------|
| **Firebase Auth** | Handles login, registration, password reset |
| **Cloud Firestore** | The main database (stores users, orders, products, etc.) |
| **Firebase Messaging (FCM)** | Sends push notifications to phones |
| **Firebase Storage** | NOT used — images are stored on Cloudinary instead |

### How the Flutter App Connects

In `main.dart`:
```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```
This runs before the app starts. `firebase_options.dart` contains the API keys
for Android, iOS, and Web.

### How the Admin Panel Connects

In `src/firebase.js`:
```javascript
const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
```
Both the app and admin panel use the **same project ID**, so they read/write the same data.

### Real-time Updates
Firestore uses **listeners** (not one-time fetches) in most places:
- Flutter: `StreamBuilder<QuerySnapshot>` — UI rebuilds automatically when data changes
- React Admin: `onSnapshot()` — component state updates automatically when data changes

This means when an admin deletes a user, the count on the dashboard updates **instantly**
without refreshing the page.

---

## 4. Firestore Collections (Database Schema)

### `users` collection
Each document ID = the user's Firebase Auth UID.

```
users/{uid}
├── fullName        : "Hamad Ali"
├── username        : "hamad"
├── email           : "hamad@example.com"
├── phone           : "+255699332524"
├── role            : "customer" | "seller" | "driver"
├── active          : true | false  (false = banned by admin)
├── deleted         : true | false  (true = soft-deleted)
├── deletedAt       : "2026-05-01T..."
├── profileComplete : true | false  (drivers only)
├── fcmToken        : "FCM_TOKEN_STRING"  (for push notifications)
├── createdAt       : Timestamp
├── location        :
│   ├── latitude    : -6.1659
│   ├── longitude   : 39.2026
│   ├── name        : "Stone Town, Zanzibar"
│   └── updatedAt   : "2026-05-01T..."
└── driverProfile   : (drivers only)
    ├── dateOfBirth     : "01/01/1995"
    ├── nationalId      : "NIDA123456"
    ├── licenseNumber   : "LIC789"
    ├── vehicleType     : "Motorcycle" | "Car" | "Bicycle" | "Pickup"
    ├── licensePlate    : "T123 ABC"
    ├── emergencyContact: "+255700000000"
    ├── idCardUrl       : "https://cloudinary.com/..."
    ├── licenseUrl      : "https://cloudinary.com/..."
    ├── dcLetterUrl     : "https://cloudinary.com/..."
    ├── status          : "pending" | "approved" | "rejected"
    └── submittedAt     : Timestamp
```

### `products` collection

```
products/{productId}
├── name            : "Fresh Tuna"
├── description     : "Caught this morning..."
├── category        : "fish" | "shrimp" | "crab" | "lobster" | "squid" | "octopus" | "other"
├── price           : 15000
├── unit            : "kg" | "g" | "piece" | "dozen"
├── stock           : 50
├── isAvailable     : true | false  (auto set to false when stock = 0)
├── imageUrl        : "https://cloudinary.com/..."
├── sellerId        : "uid_of_seller"
└── createdAt       : Timestamp
```

### `orders` collection

```
orders/{orderId}
├── customerId      : "uid_of_customer"
├── status          : "pending" | "confirmed" | "delivered" | "cancelled"
├── total           : 45000   (product subtotal)
├── grandTotal      : 51000   (total + delivery cost)
├── createdAt       : Timestamp
├── items           : [
│   {
│     productId   : "abc123"
│     name        : "Fresh Tuna"
│     price       : 15000
│     quantity    : 2
│     unit        : "kg"
│     imageUrl    : "https://..."
│     sellerId    : "uid_of_seller"
│   }
│ ]
└── delivery        : (added when customer selects a driver)
    ├── driverId        : "uid_of_driver"
    ├── driverName      : "Hamad Ali"
    ├── driverPhone     : "+255699332524"
    ├── vehicleType     : "Motorcycle"
    ├── cost            : 6000
    ├── status          : "assigned" | "picking_up" | "on_the_way" | "delivered"
    ├── requestedAt     : Timestamp
    ├── pickedUpAt      : Timestamp
    └── deliveredAt     : Timestamp
```

### `notifications` collection

```
notifications/{notifId}
├── userId      : "uid_of_recipient"
├── type        : "new_delivery" | "order_status"
├── title       : "New Delivery Request 🚀"
├── body        : "You have a new delivery from Maryam..."
├── orderId     : "order123"
├── read        : false
└── createdAt   : Timestamp
```

### `chats` collection

```
chats/{chatId}
├── participants    : ["uid_customer", "uid_driver"]
├── lastMessage     : "I am on my way"
├── lastMessageAt   : Timestamp
└── messages/       (sub-collection)
    └── {messageId}
        ├── senderId    : "uid_driver"
        ├── text        : "I am on my way"
        ├── read        : false
        └── createdAt   : Timestamp
```

### `users/{uid}/cart` sub-collection (Customer only)

```
users/{uid}/cart/{productId}
├── productId   : "abc123"
├── name        : "Fresh Tuna"
├── price       : 15000
├── unit        : "kg"
├── imageUrl    : "https://..."
├── sellerId    : "uid_of_seller"
├── quantity    : 2
└── addedAt     : Timestamp
```

---

## 5. User Roles

There are **4 roles** in the system:

### Customer
- Browses seafood products
- Adds items to cart
- Places orders
- Selects a delivery driver
- Tracks order status
- Chats with drivers
- Views order history

### Seller
- Lists seafood products for sale
- Manages stock (add/edit/deactivate/delete products)
- Views and confirms incoming orders
- Sees sales statistics on dashboard

### Driver
- Sets online/offline status
- Views available orders (pending orders needing delivery)
- Accepts delivery assignments
- Follows 2-step delivery: Pick Up from Seller → Deliver to Customer
- Uses map to navigate to seller and customer locations
- Views delivery history
- Chats with customers

### Admin (Admin Panel only)
- Manages all users (view, edit, ban, delete)
- Approves or rejects driver profiles
- Manages products
- Views and manages all orders
- Manages deliveries
- Views reports and analytics

---

## 6. Complete System Flow

### Step 1 — First Launch
```
App opens
    └── SplashScreen (3 seconds)
            ├── Fetches GPS location → saves to Firestore
            ├── Checks SharedPreferences for saved language
            │       └── No language saved? → LanguageScreen (choose English/Swahili)
            ├── Checks Firebase Auth for logged-in user
            │       └── No user? → LoginScreen
            └── User found in Firestore?
                    ├── deleted=true or active=false? → Sign out → LoginScreen
                    ├── role=customer → CustomerDashboard
                    ├── role=seller   → SellerDashboard
                    └── role=driver
                            ├── profileComplete=false → DriverProfileSetupScreen
                            └── profileComplete=true  → DriverDashboard
```

### Step 2 — Registration
```
RegisterScreen
    ├── User fills: Full Name, Username, Phone, Email, Password, Role
    ├── Firebase Auth creates account (email + password)
    ├── Firestore saves user document with role
    ├── GPS location fetched and saved to Firestore
    ├── User is logged out (must login manually)
    └── Redirected to LoginScreen
```

### Step 3 — Driver Profile Setup (Drivers only)
```
DriverProfileSetupScreen
    ├── Driver fills: DOB, National ID, License Number, Vehicle Type, Plate, Emergency Contact
    ├── Driver uploads 3 documents: National ID photo, License photo, DC Letter photo
    │       └── Images uploaded to Cloudinary → URLs saved to Firestore
    ├── Firestore: driverProfile.status = "pending", profileComplete = true
    └── Driver goes to DriverDashboard (but cannot receive orders until approved)

Admin Panel:
    ├── Admin opens User Management → finds driver → clicks View
    ├── Reviews documents (photos shown in modal)
    └── Clicks Approve → driverProfile.status = "approved"
            └── Driver now appears in delivery selection screen
```

### Step 4 — Customer Places an Order
```
CustomerDashboard → BrowseSeafoodScreen
    ├── Customer browses products (filtered by category, search)
    ├── Taps product → ProductDetailSheet opens
    ├── Taps "Add to Cart"
    │       ├── CartService checks available stock in Firestore
    │       ├── If stock available → adds to users/{uid}/cart
    │       └── Snackbar shows "Added to cart" with "View Cart" button
    │
    └── Customer taps cart icon → CartScreen
            ├── Shows all cart items with quantity controls
            ├── Customer can increase/decrease quantity (capped at stock)
            ├── Customer taps "Checkout"
            │       └── Confirmation dialog shows order summary
            ├── CartService.placeOrder() runs a Firestore transaction:
            │       ├── Creates order document (status: "pending")
            │       ├── Decrements stock for each product
            │       ├── Sets isAvailable=false if stock hits 0
            │       └── Clears cart
            └── Navigates to DeliverySelectionScreen
```

### Step 5 — Customer Selects a Driver
```
DeliverySelectionScreen
    ├── Shows all approved drivers (driverProfile.status = "approved")
    ├── Calculates distance from customer to each driver using Haversine formula
    ├── Shows distance in km for each driver
    ├── Customer selects a driver → sees grand total summary
    ├── Customer taps "Confirm Delivery"
    │       ├── Firestore order updated:
    │       │       ├── delivery.driverId, driverName, vehicleType, cost
    │       │       ├── delivery.status = "assigned"
    │       │       ├── grandTotal = product total + delivery cost
    │       │       └── status = "confirmed"
    │       └── NotificationService creates notification for driver in Firestore
    └── Customer redirected to OrdersScreen
```

### Step 6 — Driver Delivers the Order
```
DriverDashboard → ActiveDeliveryScreen
    ├── Driver sees order card with Step 1: "Pick Up from Seller"
    │       ├── Shows seller name, phone, location
    │       ├── Map button → opens Google Maps with directions to seller
    │       └── Driver taps "Picked Up — Head to Customer"
    │               └── Firestore: delivery.status = "picking_up" → "on_the_way"
    │
    └── Step 2: "Deliver to Customer"
            ├── Shows customer name, phone, location
            ├── Map button → opens Google Maps with directions to customer
            └── Driver taps "Delivered — Mark Complete"
                    ├── Firestore: order.status = "delivered"
                    ├── Firestore: delivery.status = "delivered", deliveredAt = now
                    └── NotificationService sends "Order Delivered" notification to customer
```

### Step 7 — After Delivery
```
Customer:
    └── OrderHistoryScreen shows completed orders

Driver:
    └── DeliveryHistoryScreen shows past deliveries
            └── Tap any order → bottom sheet shows customer, seller, items detail

Seller:
    └── SellerOrdersScreen shows order as "delivered"
    └── Revenue counted in dashboard stats
```

---

## 7. Flutter App — Screen by Screen

| Screen | Role | Purpose |
|--------|------|---------|
| `SplashScreen` | All | App loading, location fetch, auth check, routing |
| `LanguageScreen` | All | First-time language selection (English/Swahili) |
| `LoginScreen` | All | Email + password login |
| `RegisterScreen` | All | New account creation |
| `ForgotPasswordScreen` | All | Firebase password reset email |
| `CustomerDashboard` | Customer | Main shell with bottom nav + drawer |
| `BrowseSeafoodScreen` | Customer | Product listing with search, filter, cart |
| `CartScreen` | Customer | Cart management + checkout |
| `DeliverySelectionScreen` | Customer | Choose driver for delivery |
| `OrdersScreen` | Customer | Active orders tracking |
| `OrderHistoryScreen` | Customer | Past completed orders |
| `DeliveryPersonnelScreen` | Customer | Chat with drivers |
| `SellerDashboard` | Seller | Stats + recent orders home |
| `SellerProductsPage` | Seller | Product list with search/filter/sort |
| `AddProductScreen` | Seller | Add new product with image upload |
| `SellerOrdersScreen` | Seller | Incoming orders management |
| `DriverDashboard` | Driver | Online toggle + stats + available orders |
| `DriverProfileSetupScreen` | Driver | One-time profile + document submission |
| `ActiveDeliveryScreen` | Driver | Current deliveries with map navigation |
| `AvailableOrdersScreen` | Driver | Pending orders to accept |
| `DeliveryHistoryScreen` | Driver | Past deliveries with detail view |
| `DriverNotificationsScreen` | Driver | Delivery request notifications |
| `DriverMessagesScreen` | Driver | Chat with customers |
| `ProfileScreen` | All | View profile + update location |
| `EditProfileScreen` | All | Edit name, phone, username |
| `SettingsScreen` | All | Language toggle + app settings |
| `ChatScreen` | Customer+Driver | Real-time messaging |

---

## 8. Admin Panel — Feature by Feature

### Dashboard (Overview)
- Shows 8 real-time stat cards: Total Users, Customers, Sellers, Drivers, Total Products, Active Products, Total Orders, Pending Orders
- All counts exclude soft-deleted users
- Updates instantly via Firestore `onSnapshot`

### User Management
- Lists all active users in a paginated table (10 per page)
- Search by name, email, phone
- Filter by role (Customer/Seller/Driver)
- Sort by date, name, role, status
- **Active view:** Delete button → soft-delete (sets `deleted: true`, `active: false`)
- **Deleted view:** Delete button turns red → permanent delete (`deleteDoc`)
- Toggle button → ban/unban user (`active: false/true`)
- View button → modal with full profile + driver documents + Approve/Reject buttons

### Products Management
- Lists all products across all sellers
- Add, edit, delete products
- Toggle product availability

### Orders Management
- Lists all orders with status badges
- View order details, items, customer info
- Update order status

### Delivery Management
- Lists orders with delivery assignments
- View driver and customer details

### Reports & Analytics
- 6 KPI cards (Revenue, Orders, Delivery Rate, Avg Order, Delivery Revenue, Users)
- Revenue trend area chart (last 6 months)
- Orders per month bar chart
- Order status pie chart
- User role distribution donut chart
- New user registrations grouped bar chart
- Top products by quantity ordered
- Top drivers leaderboard
- Products stock summary with color-coded progress bars

### Settings
- Admin account management

---

## 9. Notifications System

Notifications are stored in Firestore (not sent via FCM server directly).

### How it works:
1. An event happens (e.g. customer selects a driver)
2. `NotificationService` writes a document to the `notifications` collection
3. The recipient's app has a `StreamBuilder` listening to their notifications
4. The notification appears in the app in real time
5. Unread count badge shows on the bell icon in the bottom nav

### Notification Types:
| Type | Sent to | Trigger |
|------|---------|---------|
| `new_delivery` | Driver | Customer selects that driver |
| `order_status: confirmed` | Customer | Driver assigned |
| `order_status: delivered` | Customer | Driver marks order complete |
| `order_status: cancelled` | Customer | Order cancelled |

### FCM Token:
- On login/app start, `NotificationService.saveFcmToken()` saves the device's FCM token to `users/{uid}.fcmToken`
- This token can be used by Cloud Functions to send actual push notifications to the device

---

## 10. Location System

### How location is captured:
1. **On registration** — `LocationService.getLocationData()` is called right after account creation
2. **On app launch** — SplashScreen calls `getLocationData()` for logged-in users
3. **Manual update** — Profile screen has an "Update" button that calls `getLocationData()`

### What `getLocationData()` does:
```
1. Requests location permission from the device
2. Gets GPS coordinates (latitude, longitude) using geolocator package
3. Reverse geocodes coordinates to a place name using geocoding package
   e.g. (-6.1659, 39.2026) → "Stone Town, Zanzibar"
4. Saves { latitude, longitude, name, updatedAt } to Firestore
```

### How location is used:
- **Delivery cost calculation** — Haversine formula calculates distance between customer and driver
- **Map navigation** — Driver taps Map button → Google Maps opens with directions
- **Profile display** — Shows location name in profile screen

### Delivery Cost Formula:
```
distance = haversine(customerLat, customerLng, driverLat, driverLng)  // in km

rate per km:
  Bicycle    → TShs 300/km  (min TShs 1,000)
  Motorcycle → TShs 500/km  (min TShs 2,000)
  Car        → TShs 800/km  (min TShs 4,000)
  Pickup     → TShs 1,200/km (min TShs 6,000)

cost = max(distance × rate, minimum_cost)
cost = rounded up to nearest 100
```

---

## 11. Image Uploads

Images are **not** stored in Firebase Storage. They are uploaded to **Cloudinary**.

- **Cloud Name:** `dx7jrfytj`
- **Upload Preset:** `seafoods` (unsigned preset — no API key needed)
- **API Endpoint:** `https://api.cloudinary.com/v1_1/dx7jrfytj/image/upload`

### How it works:
```
User picks image (camera or gallery) using image_picker package
    └── File sent as multipart HTTP POST to Cloudinary
            └── Cloudinary returns { secure_url: "https://res.cloudinary.com/..." }
                    └── URL saved to Firestore (product.imageUrl or driverProfile.idCardUrl etc.)
```

Used for:
- Product photos (sellers adding products)
- Driver documents (National ID, License, DC Letter)

---

## 12. State Management

The app uses **Provider** package for state management.

Only one provider exists: `LanguageProvider`

```dart
// In main.dart — wraps the entire app
ChangeNotifierProvider.value(
  value: languageProvider,
  child: MaterialApp(...)
)

// In any screen — read the current language
final lang = context.watch<LanguageProvider>();
lang.t('login')        // returns "Login" or "Ingia" depending on language
lang.isSwahili         // true if Swahili is selected
lang.setLanguage('sw') // switches to Swahili and saves to SharedPreferences
```

Everything else (user data, orders, products) is fetched directly from Firestore
using `StreamBuilder` or `FutureBuilder` — no Redux, no Bloc, no complex state.

---

## 13. Bilingual Support

The app supports **English** and **Swahili** throughout.

- Language preference is saved in `SharedPreferences` (device storage)
- All UI strings go through `lang.t('key')` which looks up the translation
- Over 80 translation keys defined in `language_provider.dart`
- Some strings are hardcoded inline with ternary: `lang.isSwahili ? 'Swahili text' : 'English text'`
- Language can be changed anytime from Settings screen

---

## 14. Key Files Reference

### Flutter App

| File | What it does |
|------|-------------|
| `lib/main.dart` | App entry point, Firebase init, Provider setup |
| `lib/firebase_options.dart` | API keys for all platforms |
| `lib/services/auth_service.dart` | register(), login(), logout(), getUserData() |
| `lib/services/cart_service.dart` | addToCart(), placeOrder(), cartStream() |
| `lib/services/location_service.dart` | getCurrentLocation(), getLocationData() |
| `lib/services/notification_service.dart` | init(), sendDeliveryNotification(), sendOrderStatusNotification() |
| `lib/providers/language_provider.dart` | t(), setLanguage(), all translations |
| `lib/screens/splash_screen.dart` | App startup logic and routing |
| `lib/screens/delivery_selection_screen.dart` | Driver selection + cost calculation |
| `lib/screens/driver_deliveries_screen.dart` | Active delivery + map + history |

### Admin Panel

| File | What it does |
|------|-------------|
| `src/firebase.js` | Firebase connection (auth + db) |
| `src/pages/Dashboard.jsx` | Main layout, routing between sections |
| `src/components/Sidebar.jsx` | Navigation sidebar |
| `src/components/Overview.jsx` | Stats dashboard cards |
| `src/components/UsersTable.jsx` | User management (view/edit/ban/delete) |
| `src/components/Reports.jsx` | Charts and analytics |

---

*Documentation generated for ZanSeaFood v1.0.0 — May 2026*
