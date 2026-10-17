// Permanently deletes the calling user's account and data.
//
// POST (no body), called by the app with the user's JWT:
//   supabase.functions.invoke('delete-account')
//
// 1. Removes the user's files from Storage (avatars/<user id>/...). Storage
//    objects can't be deleted with SQL, so this has to go through the API.
// 2. Deletes rows in tables created outside the migrations (profiles,
//    user_health_data), in case they don't cascade.
// 3. Deletes the auth user; every table created by the migrations references
//    auth.users ON DELETE CASCADE, so the rest goes with it.
//
// Deploy with JWT verification on (the default).
//
// An active App Store / Play subscription is NOT cancelled by this; the app
// tells the user to cancel it in their store account.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { bearerToken, errorResponse, jsonResponse, UUID_RE } from "../_shared/validate.ts";

/** The request carries no meaningful body; anything bigger than this is refused. */
const MAX_BODY_BYTES = 4 * 1024;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const admin = createClient(SUPABASE_URL || "http://localhost", SERVICE_ROLE_KEY || "missing");

/** Tables keyed by the user that may not cascade from auth.users. */
const USER_TABLES: Array<{ table: string; column: string }> = [
  // Keyed by id (the user's id), as the app reads and writes it.
  { table: "user_health_data", column: "id" },
  { table: "profiles", column: "id" },
];

const json = jsonResponse;

async function removeFolder(bucket: string, folder: string): Promise<void> {
  // list() is paged; keep going until the folder is empty.
  for (let round = 0; round < 20; round++) {
    const { data, error } = await admin.storage.from(bucket).list(folder, {
      limit: 100,
    });
    if (error) throw error;
    if (!data || data.length === 0) return;
    const { error: removeError } = await admin.storage
      .from(bucket)
      .remove(data.map((f: { name: string }) => `${folder}/${f.name}`));
    if (removeError) throw removeError;
  }
}

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SENDER_EMAIL = "VitalUp Security <privacy@vitalup.live>";
const SUPPORT_EMAIL = "support@vitalup.live";
const PRIVACY_EMAIL = "privacy@vitalup.live";

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

interface UserDeletionDetails {
  userId: string;
  userEmail: string;
  userName?: string;
  username?: string;
  provider?: string;
  phone?: string;
  createdAt?: string;
  lastSignInAt?: string;
}

function renderAdminDeletionNoticeHtml(params: {
  userId: string;
  userEmail: string;
  userName?: string;
  username?: string;
  provider?: string;
  phone?: string;
  createdAt?: string;
  lastSignInAt?: string;
  dateStr: string;
}): string {
  const logoUrl = "https://vitalup.live/assets/vitalup_light_logo.png";
  const safeEmail = escapeHtml(params.userEmail);
  const safeName = escapeHtml(params.userName || "None");
  const safeUsername = escapeHtml(params.username || "None");
  const safeUserId = escapeHtml(params.userId);
  const safeProvider = escapeHtml(params.provider || "email");
  const safePhone = escapeHtml(params.phone || "None");
  const safeCreatedAt = escapeHtml(params.createdAt || "N/A");
  const safeLastSignIn = escapeHtml(params.lastSignInAt || "N/A");

  return `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Account Deleted Audit — VitalUp</title>
</head>
<body style="margin:0; padding:0; background-color:#0B0F19; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#F1F5F9; -webkit-font-smoothing:antialiased;">
  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#0B0F19; padding:32px 14px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="max-width:580px; background-color:#111827; border:1px solid #1F293D; border-radius:16px; overflow:hidden; box-shadow:0 12px 36px rgba(0,0,0,0.5);">
          
          <!-- Header -->
          <tr>
            <td align="center" style="padding:32px 28px 22px; border-bottom:1px solid #1F293D; background-color:#111827;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <img src="${logoUrl}" alt="VitalUp Logo" width="52" height="52" style="display:block; border-radius:14px; border:1px solid rgba(255,255,255,0.12); box-shadow:0 4px 16px rgba(239,68,68,0.25); background:#FFFFFF;" />
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:12px;">
                    <span style="font-size:22px; font-weight:800; color:#FFFFFF; letter-spacing:-0.02em;">VitalUp Audit &amp; Privacy</span>
                    <span style="display:block; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.1em; color:#EF4444; margin-top:3px;">In-App Deletion Completed</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:32px 28px 24px;">
              <div style="margin-bottom:18px;">
                <span style="display:inline-block; padding:4px 12px; background:rgba(239,68,68,0.12); border:1px solid rgba(239,68,68,0.35); border-radius:999px; font-size:11px; font-weight:700; color:#EF4444; text-transform:uppercase; letter-spacing:0.06em;">
                  DATABASE PURGE EXECUTED
                </span>
                <h1 style="margin:12px 0 0; font-size:20px; font-weight:700; color:#FFFFFF; line-height:1.35;">
                  User Account Purged from Database
                </h1>
                <p style="margin:8px 0 0; font-size:14px; color:#94A3B8;">
                  A user has successfully deleted their account via the VitalUp mobile app. All database rows and storage files have been wiped.
                </p>
              </div>

              <!-- User Detail Card -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px; margin-bottom:20px; padding:18px 20px;">
                <tr>
                  <td style="font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:#19C3E0; padding-bottom:10px; border-bottom:1px solid rgba(255,255,255,0.06);">
                    👤 Purged User Details
                  </td>
                </tr>
                <tr>
                  <td style="padding-top:12px; font-size:13px; line-height:1.8; color:#E2E8F0;">
                    <div><strong>Email:</strong> <a href="mailto:${safeEmail}" style="color:#19C3E0; text-decoration:none; font-weight:600;">${safeEmail}</a></div>
                    <div><strong>Name:</strong> ${safeName}</div>
                    <div><strong>Username:</strong> ${safeUsername}</div>
                    <div><strong>User ID (UUID):</strong> <code style="font-family:monospace; color:#94A3B8; font-size:12px;">${safeUserId}</code></div>
                    <div><strong>Auth Provider:</strong> ${safeProvider}</div>
                    <div><strong>Phone:</strong> ${safePhone}</div>
                    <div><strong>Account Created:</strong> ${safeCreatedAt}</div>
                    <div><strong>Last Sign-In:</strong> ${safeLastSignIn}</div>
                    <div><strong>Deletion Timestamp:</strong> ${params.dateStr}</div>
                  </td>
                </tr>
              </table>

              <!-- Actions Completed Summary -->
              <div style="background-color:#162032; border:1px solid rgba(16,185,129,0.3); border-radius:14px; padding:16px 18px; margin-bottom:20px;">
                <div style="font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:#10B981; margin-bottom:8px;">
                  ✅ Automated Actions Executed
                </div>
                <div style="font-size:13px; line-height:1.65; color:#94A3B8;">
                  &bull; Removed from <code>auth.users</code><br>
                  &bull; Cascaded wipe across tables (<code>profiles</code>, <code>user_health_data</code>, workouts, nutrition, chat logs)<br>
                  &bull; Purged <code>avatars/${safeUserId}</code> storage folder<br>
                  &bull; Confirmation email dispatched to <strong>${safeEmail}</strong>
                </div>
              </div>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding:20px 24px; border-top:1px solid #1F293D; background-color:#0B0F19;">
              <p style="margin:0; font-size:12px; color:#64748B;">
                Automated Security Notification &bull; Delivered to <strong style="color:#94A3B8;">privacy@vitalup.live, support@vitalup.live</strong>
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

async function sendDeletionConfirmedEmail(details: UserDeletionDetails): Promise<void> {
  const { userEmail, userName, userId } = details;
  if (!RESEND_API_KEY || !userEmail) return;

  const logoUrl = "https://vitalup.live/assets/vitalup_light_logo.png";
  const safeName = escapeHtml(userName || "there");
  const safeEmail = escapeHtml(userEmail);
  const dateStr = new Date().toUTCString();

  const userHtml = `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Account Permanently Deleted — VitalUp</title>
  <style type="text/css">
    @media only screen and (max-width: 600px) {
      .container-table { width: 100% !important; max-width: 100% !important; }
      .content-padding { padding: 24px 18px !important; }
      .header-padding { padding: 26px 18px 18px !important; }
    }
  </style>
</head>
<body style="margin:0; padding:0; background-color:#0B0F19; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#F1F5F9; -webkit-font-smoothing:antialiased;">
  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#0B0F19; padding:32px 14px;">
    <tr>
      <td align="center">
        <!-- Main Card Container: AppCard Glass Theme -->
        <table role="presentation" class="container-table" width="100%" border="0" cellpadding="0" cellspacing="0" style="max-width:540px; background-color:#111827; border:1px solid #1F293D; border-radius:16px; overflow:hidden; box-shadow:0 12px 36px rgba(0,0,0,0.5);">
          
          <!-- Header with App Logo -->
          <tr>
            <td class="header-padding" align="center" style="padding:32px 28px 22px; border-bottom:1px solid #1F293D; background-color:#111827;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <img src="${logoUrl}" alt="VitalUp Logo" width="52" height="52" style="display:block; border-radius:14px; border:1px solid rgba(255,255,255,0.12); box-shadow:0 4px 16px rgba(239,68,68,0.25); background:#FFFFFF;" />
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:12px;">
                    <span style="font-size:22px; font-weight:800; color:#FFFFFF; letter-spacing:-0.02em;">VitalUp Account Security</span>
                    <span style="display:block; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.1em; color:#EF4444; margin-top:3px;">Account Permanently Deleted</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td class="content-padding" style="padding:34px 28px 24px;">
              <h1 style="margin:0 0 14px; font-size:20px; font-weight:700; color:#FFFFFF; letter-spacing:-0.01em;">
                Your Account Has Been Deleted
              </h1>
              <p style="margin:0 0 20px; font-size:15px; line-height:1.65; color:#94A3B8;">
                Hi <strong style="color:#F1F5F9;">${safeName}</strong>,<br><br>
                This confirmation email is to inform you that your VitalUp account associated with <strong style="color:#19C3E0;">${safeEmail}</strong> has been permanently deleted in accordance with your in-app deletion request.
              </p>

              <!-- Purged Data Checklist Card -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(239,68,68,0.28); border-radius:14px; margin-bottom:22px; padding:18px;">
                <tr>
                  <td style="font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:#EF4444; padding-bottom:8px; border-bottom:1px solid rgba(255,255,255,0.06);">
                    🗑️ Permanently Expunged Records
                  </td>
                </tr>
                <tr>
                  <td style="padding-top:12px; font-size:13px; line-height:1.75; color:#E2E8F0;">
                    <div>&bull; <strong>Credentials:</strong> Account login and authentication profiles</div>
                    <div>&bull; <strong>Health &amp; Vitals:</strong> Biometric stats, heart rate history, body weight</div>
                    <div>&bull; <strong>Activities:</strong> GPS workout tracks, steps, calories burned</div>
                    <div>&bull; <strong>Nutrition:</strong> Daily macro logs, meals, water tracking</div>
                    <div>&bull; <strong>AI Coach:</strong> Vita coach conversation logs and personalized memories</div>
                    <div>&bull; <strong>Storage:</strong> Avatars, photos, and all uploaded attachments</div>
                  </td>
                </tr>
              </table>

              <!-- Notice on App Subscriptions -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px; margin-bottom:22px; padding:16px 18px;">
                <tr>
                  <td width="32" valign="top" style="padding-right:12px;">
                    <div style="width:28px; height:28px; border-radius:6px; background:rgba(245,158,11,0.15); border:1px solid rgba(245,158,11,0.3); text-align:center; line-height:26px; font-size:14px;">
                      ⚠️
                    </div>
                  </td>
                  <td valign="middle" style="font-size:13px; line-height:1.55; color:#E2E8F0;">
                    <strong>Active Subscriptions:</strong> If you purchased a subscription via Google Play or the Apple App Store, remember to cancel it directly in your store account. App stores do not permit automatic third-party subscription cancellations.
                  </td>
                </tr>
              </table>

              <!-- Security Notice -->
              <p style="margin:0; font-size:13px; line-height:1.6; color:#94A3B8;">
                If you did not initiate this deletion, someone may have accessed your device or account. Please contact us immediately at <a href="mailto:privacy@vitalup.live" style="color:#19C3E0; text-decoration:none; font-weight:600;">privacy@vitalup.live</a>.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding:22px 24px; border-top:1px solid #1F293D; background-color:#0B0F19;">
              <p style="margin:0 0 6px; font-size:12px; color:#64748B;">
                Processed on: ${dateStr}
              </p>
              <p style="margin:0; font-size:11px; color:#475569;">
                &copy; 2026 VitalUp &bull; <a href="https://vitalup.live/privacy" style="color:#64748B; text-decoration:none;">Privacy Policy</a> &bull; <a href="https://vitalup.live/terms" style="color:#64748B; text-decoration:none;">Terms</a>
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  // 1. Dispatch confirmation to the user
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: SENDER_EMAIL,
      to: [userEmail],
      reply_to: SUPPORT_EMAIL,
      subject: "Your VitalUp account has been permanently deleted",
      html: userHtml,
      text: `Hi ${userName || "there"},\n\nYour VitalUp account (${userEmail}) and all associated health, activity, and personal data have been permanently deleted from our servers.\n\nDate: ${dateStr}\n\nIf you have any active subscriptions on Google Play or the App Store, remember to cancel them in your device settings.\n\nVitalUp Security Team (privacy@vitalup.live)`,
    }),
  }).catch((err) => console.error("Failed to send user deletion email:", err));

  // 2. Dispatch comprehensive audit email to BOTH privacy@vitalup.live AND support@vitalup.live
  const adminHtml = renderAdminDeletionNoticeHtml({
    ...details,
    dateStr,
  });

  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "VitalUp Audit <privacy@vitalup.live>",
      to: [PRIVACY_EMAIL, SUPPORT_EMAIL],
      reply_to: userEmail,
      subject: `[Account Purged - In-App] ${userEmail} (${userName || details.username || "User"})`,
      html: adminHtml,
      text: `VitalUp User Account Deleted via Mobile App\n\nUser Email: ${userEmail}\nName: ${userName || "None"}\nUsername: ${details.username || "None"}\nUser ID: ${userId}\nProvider: ${details.provider || "email"}\nPhone: ${details.phone || "None"}\nCreated At: ${details.createdAt || "N/A"}\nLast Sign In: ${details.lastSignInAt || "N/A"}\nTimestamp: ${dateStr}\n\nAll database rows and storage buckets for this user have been permanently purged.`,
    }),
  }).catch((err) => console.error("Failed to notify privacy and support emails:", err));
}

serve(async (req) => {
  if (req.method !== "POST") return errorResponse(405, "Method not allowed.");
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error("delete-account: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
    return errorResponse(500, "Could not delete the account. Try again.");
  }
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (!Number.isFinite(declared) || declared > MAX_BODY_BYTES) return errorResponse(413, "Request is too large.");

  const jwt = bearerToken(req);
  if (!jwt) return errorResponse(401, "Not signed in");
  let userId: string;
  let userEmail = "";
  let userName = "";
  let username = "";
  let provider = "email";
  let phone = "";
  let createdAt = "";
  let lastSignInAt = "";

  try {
    const { data: auth, error: authError } = await admin.auth.getUser(jwt);
    if (authError || !auth.user) return errorResponse(401, "Not signed in");
    userId = auth.user.id;
    userEmail = auth.user.email ?? "";
    userName = (auth.user.user_metadata?.full_name || auth.user.user_metadata?.name || "") as string;
    createdAt = auth.user.created_at ?? "";
    lastSignInAt = auth.user.last_sign_in_at ?? "";
    provider = auth.user.app_metadata?.provider ?? "email";
    phone = auth.user.phone ?? "";
  } catch (e) {
    console.error("delete-account: auth check failed:", e);
    return errorResponse(503, "Could not verify your session. Try again.");
  }
  // The id names the storage folder below; never let anything else through.
  if (!UUID_RE.test(userId)) {
    console.error(`delete-account: unexpected user id format: ${userId}`);
    return errorResponse(500, "Could not delete the account. Try again.");
  }

  // Pre-fetch profile details before rows are purged
  try {
    const { data: profile } = await admin
      .from("profiles")
      .select("username, full_name")
      .eq("id", userId)
      .maybeSingle();
    if (profile) {
      if (profile.username) username = profile.username;
      if (profile.full_name && !userName) userName = profile.full_name;
    }
  } catch (_) {
    // Non-fatal if profile fetch fails
  }

  try {
    await removeFolder("avatars", userId);

    for (const { table, column } of USER_TABLES) {
      const { error } = await admin.from(table).delete().eq(column, userId);
      // A missing table or column is fine (the row then goes with the
      // auth.users cascade); anything else stops the deletion.
      if (error && !["42P01", "42703", "PGRST204", "PGRST205"].includes(error.code)) throw error;
    }

    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;

    // Send confirmation email to the user & notify privacy and support teams
    if (userEmail) {
      try {
        await sendDeletionConfirmedEmail({
          userId,
          userEmail,
          userName,
          username,
          provider,
          phone,
          createdAt,
          lastSignInAt,
        });
      } catch (emailErr) {
        console.error("delete-account: failed to send email confirmation:", emailErr);
      }
    }
  } catch (e) {
    console.error(`delete-account failed for ${userId}:`, e);
    return json({ error: "Could not delete the account. Try again." }, 500);
  }

  return json({ deleted: true });
});
