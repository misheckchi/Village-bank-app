# 🏦 Village Bank App

A professional, multi-tenant full-stack mobile application built with **Flutter** and **Node.js (Express & MongoDB)** designed for community-based micro-finance (Village Banking). This platform allows multiple independent organizations and village bank groups to register, manage their members, save, borrow, and track financial performance securely under a single backend server.

---

## 🚀 Key Features

### 🏢 Multi-Tenant Organization Architecture
- **Independent Group Isolation:** Each organization operates as its own village bank with separate members, savings, loans, transaction ledgers, and logs.
- **Organization Registration Flow:** Users can submit an organization registration form with professional details (organization name, expected member count, contact details, and initial admin credentials).
- **Owner Review & Activation:** Submitted organization requests go straight to the Platform Management Portal for review and activation by the site owner.

### 👑 Platform Management Portal (Site Owner)
- **Super Admin Dashboard:** Access full platform-wide visibility across all registered organizations.
- **Organization Approval Workflow:** Approve or reject pending organization registration requests.
- **Platform Financial Overview:** Monitor aggregate system stats, total registered members, total savings, total loans, and accumulated management revenues.

### 🌐 Global Performance Analysis (`GlobalAnalyticsScreen`)
- **Cross-Organization Benchmarks:** All members can view a comparative analysis leaderboard showing how different village bank organizations are performing.
- **Performance Metrics:** View active member counts, total savings, active loans, fund utilization rates, and organization reserve pools.
- **Visual Charting:** Interactive bar chart comparing top-performing village bank organizations.

### 💬 Global Community Forum Thread (`GlobalCommunityThreadScreen`)
- **Idea Sharing Thread:** A global discussion forum open to all individuals across all organizations to post, share, and discuss ideas on how to improve organization performance.
- **Interactive Discussion:** Features idea posting with organization badges, upvoting/liking, and threaded responses.

### 💰 Revenue & Share Split Structure
- **5% Platform Management Share:** Guaranteed 5% cut on loan repayments allocated to the site owner's management portal.
- **5% Organization Reserve Share:** Guaranteed 5% cut on loan repayments allocated to the specific organization's reserve fund.
- **Customizable Member Share Percentage:** Configurable member profit yield (default 25%, adjustable between 5% - 50%) distributed back to member savings upon loan repayment.
- **In-App Share Rate Configuration:** Organization Admins and Super Admins can adjust their bank's member share percentage in real-time.

### 👤 For Members
- **Organization Login & Registration:** Log in directly under a registered organization or select an active group during signup.
- **Financial Dashboard:** Real-time view of personal savings, active loan balances, accrued interest, and total due.
- **USSD Payment Integration:** Quick USSD dialer integration for Airtel Money, TNM Mpamba, and National Bank of Malawi (626).
- **Automatic Transaction SMS Capturing:** Automated capture of transaction reference IDs from SMS on Android devices.
- **Direct & Group Support Chat:** Communicate with group members and administrators with optional image attachments.

### 🛠️ For Organization Administrators
- **Group Dashboard:** Manage community funds, verify deposits, process loan disbursements, and approve payouts/repayments.
- **Member Management:** View individual member accounts, loan statuses, and financial standing.
- **Transparent Logging:** Automatic logging of all financial activities per organization.

---

## 🛠️ Technology Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Node.js (Express.js)
- **Database:** MongoDB Atlas (Mongoose ORM)
- **State Management:** Provider
- **Design & UI:** Glassmorphism Theme (Aurum Kit)

---

## 📁 Project Structure

```text
village_bank_app/
├── android/            # Android native code & SMS listeners
├── backend/            # Node.js Express Server & API
│   ├── server.js       # Express routes, schemas & revenue logic
│   ├── .env            # Environment variables (MONGODB_URI, PORT)
│   └── package.json    # Node dependencies
├── lib/                # Flutter Frontend Application
│   ├── models/         # Organization, User, Post & Transaction models
│   ├── screens/        # UI Screens (Auth, Dashboards, Global Analytics, Forum, Chat)
│   ├── services/       # API Service & Bank Provider state manager
│   ├── utils/          # Dark/Light theme configuration
│   └── widgets/        # Glassmorphic UI containers and bar charts
└── ios/                # iOS native code
```

---

## ⚙️ Quick Start & Setup Instructions

### 1. Backend Server Setup
1. Open a terminal and navigate to `backend/`:
   ```bash
   cd village_bank_app/backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create/verify `.env` with your MongoDB connection string:
   ```env
   MONGODB_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/village_bank_db
   PORT=3000
   ```
4. Start the backend server:
   ```bash
   node server.js
   ```

### 2. Flutter Mobile Application
1. Ensure Flutter SDK is installed.
2. In the root directory, fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Verify or update the API base URL in `lib/services/api_service.dart`.
4. Launch the application:
   ```bash
   flutter run
   ```

---

## 🔑 Default Credentials

- **Site Owner (Super Admin Portal):** Phone: `owner` | Password: `password`
- **Default Organization Admin:** Phone: `admin` | Password: `password`

---

Developed with ❤️ for multi-tenant community micro-finance.
