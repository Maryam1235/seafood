# ZanSeaFood — Use Case Diagram Prompt for ChatGPT

Paste the text below directly into ChatGPT and ask it to draw the use case diagram.

---

## PROMPT TO PASTE INTO CHATGPT:

---

Please draw a UML Use Case Diagram for a system called **ZanSeaFood** — a seafood marketplace mobile application with an admin web panel.

---

### ACTORS (5 total):

1. **Customer** — uses the mobile app to buy seafood
2. **Seller** — uses the mobile app to sell seafood products
3. **Driver** — uses the mobile app to deliver orders
4. **Admin** — uses the web admin panel to manage the system
5. **Firebase** — external system (database, authentication, notifications)

---

### USE CASES PER ACTOR:

#### CUSTOMER:
- Register Account
- Login
- Reset Password
- Select Language (English / Swahili)
- Browse Seafood Products
- Search & Filter Products
- View Product Details
- Add Product to Cart
- View Cart
- Update Cart Quantity
- Remove Item from Cart
- Place Order
- Select Delivery Driver
- View Available Drivers
- Track Order Status
- View Order History
- View Active Orders
- Chat with Driver
- View Delivery Personnel
- Update Profile
- Update Location
- Change Language
- Logout

#### SELLER:
- Register Account
- Login
- Reset Password
- Add Product
- Upload Product Image
- Edit Product
- Deactivate Product
- Delete Product
- View My Products
- Search & Filter My Products
- View Incoming Orders
- Confirm Order
- View Sales Statistics
- Update Profile
- Update Location
- Change Language
- Logout

#### DRIVER:
- Register Account
- Login
- Reset Password
- Complete Profile Setup
- Upload Documents (National ID, License, DC Letter)
- Toggle Online / Offline Status
- View Available Orders
- View Active Delivery
- Navigate to Seller (Open Google Maps)
- Mark Items Picked Up
- Navigate to Customer (Open Google Maps)
- Mark Order Delivered
- View Delivery History
- View Delivery Details
- View Notifications
- Chat with Customer
- View Earnings Summary
- Update Profile
- Update Location
- Change Language
- Logout

#### ADMIN (Web Panel):
- Login to Admin Panel
- View Dashboard Statistics
- View Total Users Count
- View Total Orders Count
- View Revenue Analytics
- View Reports & Charts
- Manage Users
- View All Users
- Search & Filter Users
- View User Details
- Edit User
- Ban / Unban User
- Soft Delete User
- Permanently Delete User
- Approve Driver Profile
- Reject Driver Profile
- View Driver Documents
- Manage Products
- Add Product
- Edit Product
- Delete Product
- Manage Orders
- View All Orders
- Update Order Status
- Manage Deliveries
- View Delivery Assignments
- View Reports & Analytics
- Logout

#### FIREBASE (External System):
- Authenticate User
- Store User Data
- Store Products
- Store Orders
- Store Notifications
- Store Chat Messages
- Send Push Notification
- Save FCM Token
- Provide Real-time Updates

---

### KEY RELATIONSHIPS (Include / Extend):

**«include» relationships** (use case always includes another):
- "Place Order" **includes** "View Cart"
- "Place Order" **includes** "Select Delivery Driver"
- "Select Delivery Driver" **includes** "View Available Drivers"
- "Add Product" **includes** "Upload Product Image"
- "Complete Profile Setup" **includes** "Upload Documents"
- "Navigate to Seller" **includes** "Open Google Maps"
- "Navigate to Customer" **includes** "Open Google Maps"
- "Login" **includes** "Authenticate User" (Firebase)
- "Register Account" **includes** "Authenticate User" (Firebase)
- "Update Location" **includes** "Request GPS Permission"

**«extend» relationships** (use case optionally extends another):
- "Reset Password" **extends** "Login"
- "Select Language" **extends** "Register Account"
- "Ban User" **extends** "Manage Users"
- "Approve Driver Profile" **extends** "View User Details"
- "Reject Driver Profile" **extends** "View User Details"
- "Permanently Delete User" **extends** "Soft Delete User"
- "Chat with Driver" **extends** "Track Order Status"
- "Chat with Customer" **extends** "View Active Delivery"

---

### SYSTEM BOUNDARY:

Draw **two system boundaries**:

1. **ZanSeaFood Mobile App** — contains all Customer, Seller, and Driver use cases
2. **ZanSeaFood Admin Panel** — contains all Admin use cases

Both systems connect to **Firebase** (external actor outside both boundaries).

---

### DIAGRAM STYLE NOTES:
- Use standard UML use case notation (oval shapes for use cases, stick figures for actors)
- Place actors on the left and right sides of the diagram
- Customer, Seller, Driver on the LEFT side of the Mobile App boundary
- Admin on the RIGHT side of the Admin Panel boundary
- Firebase at the BOTTOM as an external system connected to both boundaries
- Use dashed arrows for «include» and «extend» with labels
- Group related use cases visually (e.g. Authentication group, Order Management group, Delivery group)

---
