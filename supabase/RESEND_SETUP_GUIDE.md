# Resend Integration Guide for VitalUp

This guide explains how to connect your **Resend** account to send all autonomous emails (sign-up OTPs, password recovery OTPs, notifications, and announcements) from:
- **Sender:** `VitalUp <noreply@vitalup.live>`
- **Reply-To:** `support@vitalup.live`

---

## 🚀 Part 1: Connect Resend to Supabase Auth (Zero-Code SMTP for OTPs)

Since authentication and OTP generation in VitalUp are handled by Supabase Auth (`signUp`, `verifyOTP`, `resetPasswordForEmail`), the simplest and recommended way to route all auth OTP emails through Resend is via **Supabase Custom SMTP**:

### Step-by-Step in Supabase Dashboard:
1. Open your [Supabase Dashboard](https://supabase.com/dashboard/project/iqjcfouglglncgvzmdxo).
2. Go to **Project Settings** (gear icon) &rarr; **Authentication** &rarr; scroll to **SMTP Settings**.
3. Toggle **Enable Custom SMTP** to **ON**.
4. Fill in the Resend SMTP credentials:
   - **Sender email:** `noreply@vitalup.live`
   - **Sender name:** `VitalUp`
   - **Host:** `smtp.resend.com`
   - **Port:** `465` (SSL) or `587` (TLS)
   - **Username:** `resend`
   - **Password:** `<YOUR_RESEND_API_KEY>` (e.g., `re_123456...`)
5. Click **Save**.

### Customize the OTP Email Templates:
1. In the Supabase dashboard on the left menu, go to **Authentication** &rarr; **Email Templates**.
2. Click **Confirm signup** (Registration OTP):
   - **Subject:** `Your VitalUp verification code is {{ .Token }}`
   - **Body:**
     ```html
     <h2>Welcome to VitalUp!</h2>
     <p>Your 6-digit verification code is:</p>
     <h1 style="letter-spacing: 6px; color: #38BDF8;">{{ .Token }}</h1>
     <p>This code will expire in 10 minutes.</p>
     <p>Reply to this email if you need assistance at support@vitalup.live.</p>
     ```
3. Click **Reset password** (Password recovery OTP):
   - **Subject:** `Reset your VitalUp password: {{ .Token }}`
   - **Body:**
     ```html
     <h2>Reset Your Password</h2>
     <p>Your verification code to reset your password is:</p>
     <h1 style="letter-spacing: 6px; color: #38BDF8;">{{ .Token }}</h1>
     <p>If you did not request this code, you can safely ignore this email.</p>
     <p>For help, reply to support@vitalup.live.</p>
     ```
4. Click **Save Changes**.

---

## ⚡ Part 2: Deploy the `send-email` Edge Function (For Notifications & Announcements)

We created a dedicated Edge Function at [`supabase/functions/send-email/index.ts`](file:///d:/Users/Tarun/FlutterProjects/vital_up/supabase/functions/send-email/index.ts) that calls Resend REST API directly with `from: "VitalUp <noreply@vitalup.live>"` and `reply_to: "support@vitalup.live"`.

### 1. Set the Resend Secret in Supabase:
From your terminal:
```bash
npx supabase secrets set RESEND_API_KEY="re_YOUR_KEY_HERE"
```

### 2. Deploy the function:
```bash
npx supabase functions deploy send-email --no-verify-jwt
```

---

## 📱 Part 3: Using `EmailService` in the Flutter App

An `EmailService` has been registered in the dependency injection container ([`lib/core/services/email_service.dart`](file:///d:/Users/Tarun/FlutterProjects/vital_up/lib/core/services/email_service.dart)).

### Usage Examples:

```dart
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/services/email_service.dart';

final emailService = sl<EmailService>();

// 1. Send an announcement
await emailService.sendAnnouncement(
  to: ['user@example.com'],
  title: 'Exciting New Update!',
  message: 'VitalUp v1.1 is now live with enhanced workout coaching!',
);

// 2. Send a notification
await emailService.sendNotification(
  to: 'user@example.com',
  title: 'Weekly Goal Completed 🎉',
  message: 'Congratulations! You reached your 10,000 steps streak this week.',
);

// 4. Submit a support ticket from Contact Support page
await emailService.submitSupportTicket(
  userEmail: 'user@example.com',
  userName: 'Alex Johnson',
  userId: 'user-uuid',
  category: 'Bug Report',
  subject: 'GPS disconnects after 30 minutes',
  description: 'When running outdoors, tracking stops automatically.',
  includeDiagnostics: true,
  appVersion: '1.0.0 (1)',
  osPlatform: 'android',
  deviceModel: 'Pixel 8 Pro',
);
```

When a support ticket is submitted:
1. **Ticket Delivered to Support:** `support@vitalup.live` receives the full ticket with user profile, inputs, and device diagnostics in the brand template. Resend's `reply_to` is set to the user's email, so hitting "Reply" responds straight to the user!
2. **Confirmation Sent to User:** The user receives a branded receipt email acknowledging the ticket with their details and advice that the team will respond within 24 hours.

All emails automatically dispatch with:
- **From:** `VitalUp <noreply@vitalup.live>`
- **Reply-To:** `support@vitalup.live` (or user's email on incoming tickets)
- Dark-mode responsive email template with official light logo and Cyan accents
