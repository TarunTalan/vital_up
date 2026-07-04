# VitalUp Hybrid Backend Architecture Mapping

This document maps all the features of VitalUp to the optimized hybrid backend architecture: **Supabase** (auth, database, file storage), a **Custom Backend** (Spring Boot/Python for payments, wearables, and AI coaching), and **Local Offline Caching** (Isar Database).

---

## 1. Feature Architecture Mapping Matrix

| Feature | Primary Technology | Secondary Technology | Implementation Strategy |
| :--- | :--- | :--- | :--- |
| **1. Auth & Security** | Supabase Auth | Flutter Secure Storage | Google & Email Auth directly managed by Supabase. Tokens stored locally in `FlutterSecureStorage`. |
| **2. Profile Creation** | Supabase Database | Isar Database | User profile metadata stored in Supabase `profiles` table. Cached locally for offline access. |
| **3. Steps Tracking** | Isar Database | Supabase Database | Steps logged locally to Isar first. Syncs to Supabase `step_logs` in batches when online. |
| **4. Heart Rate Tracking** | Isar Database | Supabase Database | Continuous/sampled heart rate stored locally. Synced to Supabase for historical charts. |
| **5. Sleep Tracking** | Isar Database | Supabase Database | Daily sleep duration and cycles tracked locally. Synced to Supabase `sleep_logs`. |
| **6. Water Intake Tracking** | Isar Database | Supabase Database | Water logs stored locally in Isar. Synced to Supabase `water_logs` to calculate daily goals. |
| **7. Calorie & Nutrition** | Isar Database | Custom Backend (Python/FastAPI) | Local logs stored in Isar. Food scanner images uploaded to Supabase Storage, analyzed by Python CV service. |
| **8. Streaks & Challenges** | Supabase Database | Isar Database | Database triggers in Supabase PostgreSQL calculate active streaks. Challenges templates fetched & stored. |
| **9. Push Notifications** | Supabase Edge Functions | Firebase Cloud Messaging (FCM) | Scheduled database triggers invoke Edge Functions to trigger FCM notifications. |
| **10. Health Notebook** | Supabase Storage | Supabase Database | Medical report PDFs/images uploaded securely to private Supabase S3 buckets. Metadata stored in SQL. |
| **11. AI Health Coach** | Custom Backend (Python/FastAPI) | Supabase (Vector Store) | User logs converted to embeddings, stored in Supabase PostgreSQL (`pgvector`). Python service queries vector DB. |
| **12. Booking Live Sessions** | Custom Backend (Spring Boot) | Supabase Database | Spring Boot manages coach calendars, availability blocks, and transactional booking locks. |
| **13. Payments (Live Sessions)** | Custom Backend (Spring Boot) | Stripe / Razorpay | Webhook endpoints in Spring Boot handle payment validations and update booking states in Supabase. |
| **14. Connect with Friends** | Supabase Realtime | Supabase Database | Social feeds and real-time step comparison charts using Supabase's native PostgreSQL replication stream. |
| **15. Clinician Reports** | Custom Backend (Spring Boot) | Supabase Storage | Spring Boot compiles historical user logs into PDFs (using JasperReports/iText), saving them to Storage. |
| **16. Wearable Integrations** | Custom Backend (Spring Boot/Python) | Supabase Database | Sync workers fetch wearable API data (Fitbit, Garmin, Oura) periodically and write to the database. |

---

## 2. Core Components Responsibility

### A. Supabase (The Application Engine)
* **Auth**: Coordinates email/password signup, email verification (OTP), session tokens, Google OAuth, and session persistence.
* **Database (PostgreSQL)**: Stores all structured tables: `profiles`, `logs_steps`, `logs_water`, `logs_sleep`, `logs_nutrition`, `friendships`, `challenges`, `coach_profiles`, and `bookings`. Uses PostgreSQL views and functions to compute daily/weekly statistics.
* **Storage**: Secures binary data in separate buckets:
  * `medical-reports` (Private bucket; files are fetched using timed/signed URLs).
  * `profile-pictures` / `food-images` (Public/restricted buckets).
* **Realtime**: Replicates database modifications directly to the Flutter client for social feeds and live dashboards.

### B. Custom Backend (Specialized Logic)
* **Spring Boot (Payments, Scheduling, Report Compiler)**:
  * Integration with payment gateways (Stripe/Razorpay/Google Pay) and validation of webhooks.
  * Synchronized calendars and appointment locking for coach 1:1 bookings to avoid double-bookings.
  * Server-side compilation of PDF/CSV files.
* **Python/FastAPI (AI & Wearables)**:
  * Serves LLM prompts for the AI Health Coach, creating weekly plans based on PostgreSQL vector queries (`pgvector`).
  * Wearable background sync workers (Fitbit/Garmin OAuth token exchange and data ingestion).
  * Image classification for the food camera scanner.

### C. Flutter Local Storage (Offline-First Engine)
* **Isar Database**: Stores logs locally. Whenever the app performs queries or writes logs, it interacts directly with Isar.
* **Sync Queue**: A background service that periodically pushes local logs that have `isSynced = false` to the Supabase database.
* **Flutter Secure Storage**: Persists JWT tokens, refreshing them automatically via the Dio Authenticator interceptor.

---

## 3. JWT Handshake & Security Workflow

To securely invoke custom backend operations (e.g., booking a coach) using the Supabase authenticated session:

```
Flutter Client             Supabase              Custom Server (Spring)
      │                       │                            │
      │ 1. Sign In / OAuth    │                            │
      ├──────────────────────>│                            │
      │ 2. JWT & Refresh Token│                            │
      <───────────────────────┤                            │
      │                       │                            │
      │ 3. POST /bookings (Auth: Bearer JWT)               │
      ├───────────────────────────────────────────────────>│
      │                       │                            │
      │                       │ 4. Read JWT Secret / Keys  │
      │                       │<───────────────────────────┤
      │                       │ 5. Secret Key verified     │
      │                       │───────────────────────────>│
      │                       │                            │
      │                       │ 6. Access DB (write block) │
      │                       │<───────────────────────────┤
      │ 7. Booking Confirmed  │                            │
      <────────────────────────────────────────────────────┤
```

1. **Sign In**: The user authenticates via the Flutter client using Supabase. Supabase returns an Access Token (JWT) signed using HS256/RS256.
2. **Authorized API Call**: The Flutter client calls the Custom Server (Spring Boot/Python) with the header: `Authorization: Bearer <Supabase_JWT>`.
3. **Token Verification**: The custom server verifies the signature of the JWT using Supabase's public JWT secret. Once verified, the server extracts the user's ID (`sub` claim) securely.
4. **Data Sync**: The custom server performs the booking logic, writes the transaction to PostgreSQL, and returns a success response to the Flutter client.
