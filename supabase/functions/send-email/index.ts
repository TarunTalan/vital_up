// Edge Function to send autonomous emails (OTPs, notifications, announcements) via Resend.
//
// Sender: VitalUp <noreply@vitalup.live>
// Reply-To: support@vitalup.live
//
// Dual-mode handler:
// 1. Supabase Auth "Send Email" Hook (for automated signup/recovery OTPs)
// 2. Support tickets (signed-in app users) and website deletion requests.
//    There is no "send anything to anyone" mode: that made it an open relay.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import {
  bearerToken,
  cleanText,
  handleError,
  HttpError,
  jsonResponse,
  KB,
  parseJsonObject,
  readTextBody,
  requireMethod,
} from "../_shared/validate.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SENDER_EMAIL = "VitalUp <noreply@vitalup.live>";
const SUPPORT_SENDER = "VitalUp Support <support@vitalup.live>";
const PRIVACY_SENDER = "VitalUp Privacy Desk <privacy@vitalup.live>";
const REPLY_TO_EMAIL = "support@vitalup.live";

const PRIVACY_EMAIL = "privacy@vitalup.live";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function corsJsonResponse(body: unknown, status = 200): Response {
  return jsonResponse(body, status, CORS_HEADERS);
}

interface ResendPayload {
  from: string;
  to: string[];
  reply_to: string;
  subject: string;
  html: string;
  text?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: CORS_HEADERS,
    });
  }

  try {
    requireMethod(req, "POST");

    if (!RESEND_API_KEY) {
      console.error("send-email: RESEND_API_KEY secret is not set.");
      throw new HttpError(500, "Email service is temporarily unavailable.");
    }

    // Raw text first: the auth hook signature covers the exact body.
    const raw = await readTextBody(req, 64 * KB);
    // deno-lint-ignore no-explicit-any
    const payload = parseJsonObject(raw) as Record<string, any>;

    // ------------------------------------------------------------------------
    // CASE 1: Supabase Auth "Send Email" Hook (signup / recovery codes)
    // ------------------------------------------------------------------------
    if (payload.user && payload.email_data) {
      // Only GoTrue may use this path: anyone else could send "verification
      // codes" with any content to any address.
      verifyAuthHook(req, raw);

      const recipient = payload.user.email;
      const { token, email_action_type } = payload.email_data;

      if (!recipient || !token) {
        throw new HttpError(400, "Recipient email and OTP token are required.");
      }
      const code = escapeHtml(String(token));

      const isRecovery = email_action_type === "recovery";
      const subject = isRecovery
        ? `Reset your VitalUp password: ${code}`
        : `Your VitalUp verification code is ${code}`;

      const title = isRecovery ? "Reset Your Password" : "Verify Your Account";
      const message = isRecovery
        ? "We received a request to reset your VitalUp password. Use the verification code below to proceed:"
        : "Welcome to VitalUp! Use the 6-digit verification code below to complete your sign-up:";

      const html = renderOtpHtml({ title, message, token: code });

      await dispatchResend({
        from: SENDER_EMAIL,
        reply_to: REPLY_TO_EMAIL,
        to: [recipient],
        subject,
        html,
        text: `${title}\n\n${message}\n\nCode: ${code}\n\nThis code will expire in 10 minutes. Reply to: ${REPLY_TO_EMAIL}`,
      });

      return corsJsonResponse({ success: true });
    }

    // ------------------------------------------------------------------------
    // CASE 2a: Support ticket from the app (signed in only)
    // ------------------------------------------------------------------------
    if (payload.type === "support_ticket") {
      // Who it's from comes from the verified session, never the body, so a
      // ticket can't send a "confirmation" to someone else's inbox.
      const user = await requireUser(req);
      const userEmail = user.email;
      if (!userEmail) throw new HttpError(400, "Your account has no email address.");
      await enforceRecipientLimit(userEmail);

      const catLabel = cleanText(payload.category, 60) || "General Inquiry";
      const subj = cleanText(payload.subject, 120) || catLabel;
      const desc = cleanText(payload.description, 4000, { multiline: true });
      if (!desc) throw new HttpError(400, "Please describe the problem.");
      const userName = cleanText(payload.user_name, 80) || undefined;
      const createdAt = new Date().toISOString();

      await dispatchResend({
        from: SUPPORT_SENDER,
        to: [REPLY_TO_EMAIL],
        reply_to: userEmail,
        subject: `[Support Ticket - ${catLabel}] ${subj}`,
        html: renderSupportTicketHtml({
          user_email: userEmail,
          user_name: userName,
          user_id: user.id,
          category: catLabel,
          subject: subj,
          description: desc,
          include_diagnostics: payload.include_diagnostics === true,
          app_version: cleanText(payload.app_version, 40) || undefined,
          os_platform: cleanText(payload.os_platform, 40) || undefined,
          device_model: cleanText(payload.device_model, 120) || undefined,
          created_at: createdAt,
        }),
        text: `VitalUp Support Ticket\n\nFrom: ${userEmail} (${userName || "User"})\nUser ID: ${user.id}\nCategory: ${catLabel}\nSubject: ${subj}\n\nDescription:\n${desc}\n\nTimestamp: ${createdAt}`,
      });

      await dispatchResend({
        from: SUPPORT_SENDER,
        to: [userEmail],
        reply_to: REPLY_TO_EMAIL,
        subject: "We received your support request [VitalUp Support]",
        html: renderSupportConfirmationHtml({
          user_name: userName,
          category: catLabel,
          subject: subj,
          description: desc,
        }),
        text: `Hi ${userName || "there"},\n\nThank you for reaching out to VitalUp Support. We have received your request and will respond within 24 hours.\n\nVitalUp Team (support@vitalup.live)`,
      });

      return corsJsonResponse({ success: true });
    }

    // ------------------------------------------------------------------------
    // CASE 2b: Account deletion request from vitalup.live (signed out)
    // ------------------------------------------------------------------------
    if (payload.type === "account_deletion_request") {
      const userEmail = cleanText(payload.user_email, 254);
      if (!EMAIL_RE.test(userEmail)) {
        throw new HttpError(400, "Enter a valid email address.");
      }
      // Open to anyone (Play requires a web form), so each address gets
      // only a few receipts a day and the receipt carries no free text.
      await enforceRecipientLimit(userEmail);

      const scope = cleanText(payload.scope, 80) || "Complete Account & All Data";
      const desc = cleanText(payload.description, 2000, { multiline: true }) ||
        "Account deletion requested via website form.";
      const createdAt = new Date().toISOString();

      await dispatchResend({
        from: PRIVACY_SENDER,
        to: [PRIVACY_EMAIL, REPLY_TO_EMAIL],
        reply_to: userEmail,
        subject: `[Action Required - Deletion Request] ${userEmail}`,
        html: renderDeletionAdminHtml({
          user_email: userEmail,
          scope,
          description: desc,
          created_at: createdAt,
        }),
        text: `VitalUp Account Deletion Request\n\nUser Email: ${userEmail}\nScope: ${scope}\nDetails: ${desc}\nTimestamp: ${createdAt}`,
      });

      await dispatchResend({
        from: PRIVACY_SENDER,
        to: [userEmail],
        reply_to: PRIVACY_EMAIL,
        subject: "VitalUp Account Deletion Request Received [Pending Verification]",
        html: renderDeletionRequestReceiptHtml({ user_email: userEmail, scope, description: "" }),
        text: `Hi there,\n\nWe have received a request to delete the VitalUp account for ${userEmail}.\n\nScope: ${scope}\nStatus: Pending verification (72-hour processing window)\n\nIf you didn't ask for this, reply to this email.\n\nVitalUp Privacy Team (privacy@vitalup.live)`,
      });

      return corsJsonResponse({ success: true });
    }

    // Anything else (the old "send any email to anyone" mode) is refused.
    throw new HttpError(400, "Unsupported request.");
  } catch (err) {
    return handleError(err, "send-email", CORS_HEADERS);
  }
});

const EMAIL_RE = /^[^\s@<>"']{1,64}@[^\s@<>"']{1,190}\.[a-z]{2,24}$/i;

/** Emails one address may receive from this function per day. */
const MAX_PER_RECIPIENT_PER_DAY = 3;

let _admin: ReturnType<typeof createClient> | null = null;
function admin() {
  _admin ??= createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
  return _admin;
}

/** The signed-in caller, from the request's JWT. */
async function requireUser(req: Request): Promise<{ id: string; email?: string }> {
  const token = bearerToken(req);
  if (!token) throw new HttpError(401, "Please sign in again.");
  const { data, error } = await admin().auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Please sign in again.");
  return { id: data.user.id, email: data.user.email ?? undefined };
}

/**
 * Records a send to [email] and refuses past the daily cap (table
 * email_send_log, service role only). Fails closed: if the log can't be
 * read, nothing is sent.
 */
async function enforceRecipientLimit(email: string): Promise<void> {
  const recipient = email.trim().toLowerCase();
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error } = await admin()
    .from("email_send_log")
    .select("id", { count: "exact", head: true })
    .eq("recipient", recipient)
    .gte("sent_at", since);
  if (error) {
    console.error("send-email: rate limit check failed", error.code);
    throw new HttpError(503, "Couldn't send right now. Try again later.");
  }
  if ((count ?? 0) >= MAX_PER_RECIPIENT_PER_DAY) {
    throw new HttpError(429, "Too many requests. Try again tomorrow.");
  }
  const { error: insertError } = await admin()
    .from("email_send_log")
    .insert({ recipient });
  if (insertError) {
    console.error("send-email: rate limit log failed", insertError.code);
    throw new HttpError(503, "Couldn't send right now. Try again later.");
  }
}

/**
 * Checks the Standard Webhooks signature GoTrue puts on Send Email hook
 * calls (secret SEND_EMAIL_HOOK_SECRET, "v1,whsec_..."). Without the secret
 * the hook path is closed.
 */
function verifyAuthHook(req: Request, raw: string): void {
  const secret = (Deno.env.get("SEND_EMAIL_HOOK_SECRET") ?? "").replace(/^v1,/, "");
  if (!secret) {
    console.error("send-email: SEND_EMAIL_HOOK_SECRET is not set; refusing hook call.");
    throw new HttpError(401, "Unauthorized.");
  }
  try {
    new Webhook(secret).verify(raw, Object.fromEntries(req.headers));
  } catch {
    throw new HttpError(401, "Unauthorized.");
  }
}

/** Call Resend REST API */
async function dispatchResend(data: ResendPayload): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  if (!res.ok) {
    const errorBody = await res.text().catch(() => "");
    console.error(`Resend API failed (${res.status}): ${errorBody}`);
    throw new HttpError(502, `Failed to send email via Resend: ${res.statusText}`);
  }
}

/** Professional App-Themed OTP HTML Template */
function renderOtpHtml(params: { title: string; message: string; token: string }): string {
  const logoUrl = "https://vitalup.live/assets/vitalup_light_logo.png";
  
  return `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${params.title} — VitalUp</title>
  <style type="text/css">
    @media only screen and (max-width: 600px) {
      .container-table { width: 100% !important; max-width: 100% !important; }
      .content-padding { padding: 24px 20px !important; }
      .header-padding { padding: 26px 20px 18px !important; }
      .otp-digit { font-size: 28px !important; letter-spacing: 6px !important; }
    }
  </style>
</head>
<body style="margin:0; padding:0; background-color:#0B0F19; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#F1F5F9; -webkit-font-smoothing:antialiased;">
  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#0B0F19; padding:32px 14px;">
    <tr>
      <td align="center">
        <!-- Main Card Container: AppCard Glass Theme (radius: 16px, border: 1px solid #1F293D) -->
        <table role="presentation" class="container-table" width="100%" border="0" cellpadding="0" cellspacing="0" style="max-width:540px; background-color:#111827; border:1px solid #1F293D; border-radius:16px; overflow:hidden; box-shadow:0 12px 36px rgba(0,0,0,0.45);">
          
          <!-- Header with App Light Logo -->
          <tr>
            <td class="header-padding" align="center" style="padding:32px 28px 22px; border-bottom:1px solid #1F293D; background-color:#111827;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <img src="${logoUrl}" alt="VitalUp Logo" width="52" height="52" style="display:block; border-radius:14px; border:1px solid rgba(255,255,255,0.12); box-shadow:0 4px 16px rgba(25,195,224,0.25); background:#FFFFFF;" />
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:12px;">
                    <span style="font-size:22px; font-weight:800; color:#FFFFFF; letter-spacing:-0.02em;">VitalUp</span>
                    <span style="display:block; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.1em; color:#19C3E0; margin-top:3px;">Health &amp; Fitness</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td class="content-padding" style="padding:34px 32px 28px;">
              <h1 style="margin:0 0 12px; font-size:20px; font-weight:700; color:#FFFFFF; letter-spacing:-0.01em;">${params.title}</h1>
              <p style="margin:0 0 24px; font-size:15px; line-height:1.65; color:#94A3B8;">
                ${params.message}
              </p>
              
              <!-- App OTP Card (Matching AppCard with Cyan Border) -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(25,195,224,0.3); border-radius:14px; margin-bottom:22px;">
                <tr>
                  <td align="center" style="padding:22px 16px;">
                    <div style="font-size:12px; font-weight:600; text-transform:uppercase; letter-spacing:0.08em; color:#94A3B8; margin-bottom:8px;">Verification Code</div>
                    <span class="otp-digit" style="font-family:'JetBrains Mono', Consolas, Monaco, 'Courier New', monospace; font-size:36px; font-weight:800; letter-spacing:10px; color:#19C3E0; display:inline-block; margin-left:10px;">${params.token}</span>
                  </td>
                </tr>
              </table>
              
              <!-- App Info Card Component (Full 4-corner rounded card, no vertical bar) -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px; margin-bottom:24px;">
                <tr>
                  <td style="padding:16px 18px;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td width="36" valign="top" style="padding-right:12px;">
                          <div style="width:32px; height:32px; border-radius:8px; background:rgba(25,195,224,0.15); border:1px solid rgba(25,195,224,0.3); text-align:center; line-height:30px; font-size:15px;">
                            ⏱️
                          </div>
                        </td>
                        <td valign="middle" style="font-size:13px; line-height:1.55; color:#E2E8F0;">
                          <strong>Expires in 10 minutes.</strong> Never share this code with anyone. VitalUp representatives will never ask for your code.
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="margin:0; font-size:13px; line-height:1.55; color:#64748B;">
                If you did not make this request, you can safely disregard this email or contact support at <a href="mailto:support@vitalup.live" style="color:#19C3E0; text-decoration:none;">support@vitalup.live</a>.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding:22px 24px; border-top:1px solid #1F293D; background-color:#0B0F19;">
              <p style="margin:0 0 8px; font-size:12px; color:#64748B;">
                Sent from <strong style="color:#94A3B8;">noreply@vitalup.live</strong> &bull; Reply to: <a href="mailto:support@vitalup.live" style="color:#19C3E0; text-decoration:none;">support@vitalup.live</a>
              </p>
              <p style="margin:0; font-size:11px; color:#475569;">
                &copy; 2026 VitalUp Platform &bull; <a href="https://vitalup.live/privacy" style="color:#64748B; text-decoration:none;">Privacy Policy</a> &bull; <a href="https://vitalup.live/terms" style="color:#64748B; text-decoration:none;">Terms</a> &bull; <a href="https://vitalup.live" style="color:#19C3E0; text-decoration:none;">vitalup.live</a>
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

/** Escapes HTML characters to prevent XSS/injection in rendered emails */
function escapeHtml(unsafe: string): string {
  return (unsafe || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

/** Professional Email Template for support@vitalup.live containing user details and ticket inputs */
function renderSupportTicketHtml(params: {
  user_email: string;
  user_name?: string;
  user_id?: string;
  category: string;
  subject: string;
  description: string;
  include_diagnostics: boolean;
  app_version?: string;
  os_platform?: string;
  device_model?: string;
  created_at: string;
}): string {
  const logoUrl = "https://vitalup.live/assets/vitalup_light_logo.png";
  const safeEmail = escapeHtml(params.user_email);
  const safeName = escapeHtml(params.user_name || "Unspecified");
  const safeCategory = escapeHtml(params.category);
  const safeSubject = escapeHtml(params.subject);
  const formattedDescription = escapeHtml(params.description).replace(/\r?\n/g, "<br>");
  const safeUserId = escapeHtml(params.user_id || "Guest / Not signed in");

  return `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>[Support Ticket] ${safeSubject} — VitalUp</title>
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
        <!-- Main Card Container: AppCard Glass Theme (radius: 16px, border: 1px solid #1F293D) -->
        <table role="presentation" class="container-table" width="100%" border="0" cellpadding="0" cellspacing="0" style="max-width:580px; background-color:#111827; border:1px solid #1F293D; border-radius:16px; overflow:hidden; box-shadow:0 12px 36px rgba(0,0,0,0.5);">
          
          <!-- Header with App Light Logo -->
          <tr>
            <td class="header-padding" align="center" style="padding:32px 28px 22px; border-bottom:1px solid #1F293D; background-color:#111827;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <img src="${logoUrl}" alt="VitalUp Logo" width="52" height="52" style="display:block; border-radius:14px; border:1px solid rgba(255,255,255,0.12); box-shadow:0 4px 16px rgba(25,195,224,0.25); background:#FFFFFF;" />
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:12px;">
                    <span style="font-size:22px; font-weight:800; color:#FFFFFF; letter-spacing:-0.02em;">VitalUp Helpdesk</span>
                    <span style="display:block; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.1em; color:#19C3E0; margin-top:3px;">New Support Ticket</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td class="content-padding" style="padding:32px 28px 24px;">
              <!-- Ticket Badge & Subject -->
              <div style="margin-bottom:18px;">
                <span style="display:inline-block; padding:4px 12px; background:rgba(25,195,224,0.12); border:1px solid rgba(25,195,224,0.35); border-radius:999px; font-size:11px; font-weight:700; color:#19C3E0; text-transform:uppercase; letter-spacing:0.06em;">
                  ${safeCategory}
                </span>
                <h1 style="margin:12px 0 0; font-size:20px; font-weight:700; color:#FFFFFF; line-height:1.35; letter-spacing:-0.01em;">
                  ${safeSubject}
                </h1>
              </div>

              <!-- User Information Card (AppCard component: 14px radius, uniform border) -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px; margin-bottom:20px; padding:16px 18px;">
                <tr>
                  <td style="font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:#19C3E0; padding-bottom:8px; border-bottom:1px solid rgba(255,255,255,0.06);">
                    👤 User Contact &amp; Profile Details
                  </td>
                </tr>
                <tr>
                  <td style="padding-top:10px; font-size:13px; line-height:1.7; color:#E2E8F0;">
                    <div><strong>Email:</strong> <a href="mailto:${safeEmail}" style="color:#19C3E0; text-decoration:none; font-weight:600;">${safeEmail}</a></div>
                    <div><strong>Name:</strong> ${safeName}</div>
                    <div><strong>User ID:</strong> <code style="font-family:monospace; color:#94A3B8; font-size:12px;">${safeUserId}</code></div>
                  </td>
                </tr>
              </table>

              <!-- Ticket Description (AppCard component) -->
              <div style="margin-bottom:20px;">
                <div style="font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:#94A3B8; margin-bottom:8px;">
                  📝 Issue Description
                </div>
                <div style="background-color:#162032; border:1px solid rgba(25,195,224,0.28); border-radius:14px; padding:18px; font-size:14px; line-height:1.65; color:#F1F5F9;">
                  ${formattedDescription}
                </div>
              </div>

              ${params.include_diagnostics ? `
              <!-- Diagnostics & Device Environment (AppCard component) -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px; margin-bottom:22px; padding:16px 18px;">
                <tr>
                  <td style="font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:#94A3B8; padding-bottom:8px; border-bottom:1px solid rgba(255,255,255,0.06);">
                    ⚙️ Device &amp; App Diagnostics
                  </td>
                </tr>
                <tr>
                  <td style="padding-top:10px; font-size:12px; line-height:1.7; color:#94A3B8;">
                    <div>&bull; <strong>App Version:</strong> ${escapeHtml(params.app_version || "1.0.0")}</div>
                    <div>&bull; <strong>Platform / OS:</strong> ${escapeHtml(params.os_platform || "Unknown")}</div>
                    <div>&bull; <strong>Device Model:</strong> ${escapeHtml(params.device_model || "Unknown")}</div>
                    <div>&bull; <strong>Timestamp:</strong> ${escapeHtml(params.created_at)}</div>
                  </td>
                </tr>
              </table>
              ` : ""}

              <!-- App Info Card Component (Full 4-corner rounded card, no vertical bar) -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px;">
                <tr>
                  <td style="padding:16px 18px;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td width="36" valign="top" style="padding-right:12px;">
                          <div style="width:32px; height:32px; border-radius:8px; background:rgba(25,195,224,0.15); border:1px solid rgba(25,195,224,0.3); text-align:center; line-height:30px; font-size:15px;">
                            💡
                          </div>
                        </td>
                        <td valign="middle" style="font-size:13px; line-height:1.55; color:#E2E8F0;">
                          <strong>Quick Reply:</strong> Hit <strong>Reply</strong> in your email client to respond directly to <a href="mailto:${safeEmail}" style="color:#19C3E0; text-decoration:none; font-weight:600;">${safeEmail}</a>.
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding:20px 24px; border-top:1px solid #1F293D; background-color:#0B0F19;">
              <p style="margin:0; font-size:12px; color:#64748B;">
                Sent via VitalUp In-App Support &bull; Delivery target: <strong style="color:#94A3B8;">support@vitalup.live</strong>
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

/** Professional Confirmation Email sent to the user acknowledging receipt of their support ticket */
function renderSupportConfirmationHtml(params: {
  user_name?: string;
  category: string;
  subject: string;
  description: string;
}): string {
  const logoUrl = "https://vitalup.live/assets/vitalup_light_logo.png";
  const safeName = escapeHtml(params.user_name || "there");
  const safeCategory = escapeHtml(params.category);
  const safeSubject = escapeHtml(params.subject);
  const formattedDescription = escapeHtml(params.description).replace(/\r?\n/g, "<br>");

  return `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>We received your request — VitalUp Support</title>
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
        <!-- Main Card Container: AppCard Glass Theme (radius: 16px, border: 1px solid #1F293D) -->
        <table role="presentation" class="container-table" width="100%" border="0" cellpadding="0" cellspacing="0" style="max-width:540px; background-color:#111827; border:1px solid #1F293D; border-radius:16px; overflow:hidden; box-shadow:0 12px 36px rgba(0,0,0,0.45);">
          
          <!-- Header with App Light Logo -->
          <tr>
            <td class="header-padding" align="center" style="padding:32px 28px 22px; border-bottom:1px solid #1F293D; background-color:#111827;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <img src="${logoUrl}" alt="VitalUp Logo" width="52" height="52" style="display:block; border-radius:14px; border:1px solid rgba(255,255,255,0.12); box-shadow:0 4px 16px rgba(25,195,224,0.25); background:#FFFFFF;" />
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:12px;">
                    <span style="font-size:22px; font-weight:800; color:#FFFFFF; letter-spacing:-0.02em;">VitalUp Support</span>
                    <span style="display:block; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.1em; color:#19C3E0; margin-top:3px;">Ticket Received</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td class="content-padding" style="padding:34px 28px 24px;">
              <h1 style="margin:0 0 14px; font-size:20px; font-weight:700; color:#FFFFFF; letter-spacing:-0.01em;">
                We've Received Your Request
              </h1>
              <p style="margin:0 0 20px; font-size:15px; line-height:1.65; color:#94A3B8;">
                Hi <strong style="color:#F1F5F9;">${safeName}</strong>,<br><br>
                Thank you for contacting VitalUp Support! We’ve received your inquiry and our team is already reviewing it. We typically respond within <strong>24 hours</strong>.
              </p>

              <!-- Ticket Summary Card (AppCard component: 14px radius, uniform cyan border) -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(25,195,224,0.28); border-radius:14px; margin-bottom:22px; padding:18px;">
                <tr>
                  <td>
                    <span style="display:inline-block; padding:3px 10px; background:rgba(25,195,224,0.12); border:1px solid rgba(25,195,224,0.3); border-radius:999px; font-size:10px; font-weight:700; color:#19C3E0; text-transform:uppercase; letter-spacing:0.06em; margin-bottom:10px;">
                      ${safeCategory}
                    </span>
                    <div style="font-size:16px; font-weight:700; color:#FFFFFF; margin-bottom:8px;">
                      ${safeSubject}
                    </div>
                    <div style="font-size:13px; line-height:1.6; color:#94A3B8; max-height:220px; overflow:hidden;">
                      ${formattedDescription}
                    </div>
                  </td>
                </tr>
              </table>

              <!-- App Info Card Component (Full 4-corner rounded card, no vertical bar) -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px; margin-bottom:24px;">
                <tr>
                  <td style="padding:16px 18px;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td width="36" valign="top" style="padding-right:12px;">
                          <div style="width:32px; height:32px; border-radius:8px; background:rgba(25,195,224,0.15); border:1px solid rgba(25,195,224,0.3); text-align:center; line-height:30px; font-size:15px;">
                            💬
                          </div>
                        </td>
                        <td valign="middle" style="font-size:13px; line-height:1.55; color:#E2E8F0;">
                          <strong>Need to add screenshots or more details?</strong><br>
                          Simply reply directly to this email at any time. Our team will receive your follow-up immediately.
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="margin:0; font-size:13px; line-height:1.55; color:#64748B;">
                In the meantime, feel free to check our help center or return to your fitness tracking in the app.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding:22px 24px; border-top:1px solid #1F293D; background-color:#0B0F19;">
              <p style="margin:0 0 8px; font-size:12px; color:#64748B;">
                Sent from <strong style="color:#94A3B8;">noreply@vitalup.live</strong> &bull; Direct support: <a href="mailto:support@vitalup.live" style="color:#19C3E0; text-decoration:none;">support@vitalup.live</a>
              </p>
              <p style="margin:0; font-size:11px; color:#475569;">
                &copy; 2026 VitalUp Platform &bull; <a href="https://vitalup.live/privacy" style="color:#64748B; text-decoration:none;">Privacy Policy</a> &bull; <a href="https://vitalup.live/terms" style="color:#64748B; text-decoration:none;">Terms</a> &bull; <a href="https://vitalup.live" style="color:#19C3E0; text-decoration:none;">vitalup.live</a>
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

/** Admin Alert Email sent to privacy@vitalup.live & support@vitalup.live when deletion requested */
function renderDeletionAdminHtml(params: {
  user_email: string;
  scope: string;
  description: string;
  created_at: string;
}): string {
  const logoUrl = "https://vitalup.live/assets/vitalup_light_logo.png";
  const safeEmail = escapeHtml(params.user_email);
  const safeScope = escapeHtml(params.scope);
  const formattedDescription = escapeHtml(params.description).replace(/\r?\n/g, "<br>");

  return `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Action Required: Account Deletion Request</title>
</head>
<body style="margin:0; padding:0; background-color:#0B0F19; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#F1F5F9; -webkit-font-smoothing:antialiased;">
  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#0B0F19; padding:32px 14px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="max-width:580px; background-color:#111827; border:1px solid #1F293D; border-radius:16px; overflow:hidden; box-shadow:0 12px 36px rgba(0,0,0,0.5);">
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
                    <span style="font-size:22px; font-weight:800; color:#FFFFFF; letter-spacing:-0.02em;">VitalUp Privacy Desk</span>
                    <span style="display:block; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.1em; color:#EF4444; margin-top:3px;">Account Deletion Request</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 28px 24px;">
              <div style="margin-bottom:18px;">
                <span style="display:inline-block; padding:4px 12px; background:rgba(239,68,68,0.12); border:1px solid rgba(239,68,68,0.35); border-radius:999px; font-size:11px; font-weight:700; color:#EF4444; text-transform:uppercase; letter-spacing:0.06em;">
                  URGENT PRIVACY ACTION
                </span>
                <h1 style="margin:12px 0 0; font-size:20px; font-weight:700; color:#FFFFFF; line-height:1.35;">
                  Web Account Deletion Requested
                </h1>
              </div>
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px; margin-bottom:20px; padding:16px 18px;">
                <tr>
                  <td style="font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:#19C3E0; padding-bottom:8px; border-bottom:1px solid rgba(255,255,255,0.06);">
                    👤 Target Account Information
                  </td>
                </tr>
                <tr>
                  <td style="padding-top:10px; font-size:13px; line-height:1.75; color:#E2E8F0;">
                    <div><strong>Account Email:</strong> <a href="mailto:${safeEmail}" style="color:#19C3E0; text-decoration:none; font-weight:600;">${safeEmail}</a></div>
                    <div><strong>Requested Scope:</strong> ${safeScope}</div>
                    <div><strong>Timestamp:</strong> ${escapeHtml(params.created_at)}</div>
                  </td>
                </tr>
              </table>
              <div style="margin-bottom:20px;">
                <div style="font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:#94A3B8; margin-bottom:8px;">
                  📝 Notes / Reason Provided
                </div>
                <div style="background-color:#162032; border:1px solid rgba(239,68,68,0.28); border-radius:14px; padding:18px; font-size:14px; line-height:1.65; color:#F1F5F9;">
                  ${formattedDescription}
                </div>
              </div>
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px;">
                <tr>
                  <td style="padding:16px 18px;">
                    <div style="font-size:13px; line-height:1.55; color:#E2E8F0;">
                      <strong>Action Window:</strong> 72 hours under Google Play Store and GDPR policies. Verify account in Supabase Authentication and execute permanent deletion.
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:20px 24px; border-top:1px solid #1F293D; background-color:#0B0F19;">
              <p style="margin:0; font-size:12px; color:#64748B;">
                Automated privacy routing &bull; Targets: <strong style="color:#94A3B8;">privacy@vitalup.live, support@vitalup.live</strong>
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

/** Professional Confirmation Email sent to the user acknowledging their deletion request */
function renderDeletionRequestReceiptHtml(params: {
  user_email: string;
  user_name?: string;
  scope: string;
  description: string;
}): string {
  const logoUrl = "https://vitalup.live/assets/vitalup_light_logo.png";
  const safeName = escapeHtml(params.user_name || "there");
  const safeEmail = escapeHtml(params.user_email);
  const safeScope = escapeHtml(params.scope);

  return `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Account Deletion Request Received — VitalUp</title>
</head>
<body style="margin:0; padding:0; background-color:#0B0F19; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#F1F5F9; -webkit-font-smoothing:antialiased;">
  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#0B0F19; padding:32px 14px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="max-width:540px; background-color:#111827; border:1px solid #1F293D; border-radius:16px; overflow:hidden; box-shadow:0 12px 36px rgba(0,0,0,0.45);">
          <tr>
            <td align="center" style="padding:32px 28px 22px; border-bottom:1px solid #1F293D; background-color:#111827;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <img src="${logoUrl}" alt="VitalUp Logo" width="52" height="52" style="display:block; border-radius:14px; border:1px solid rgba(255,255,255,0.12); box-shadow:0 4px 16px rgba(25,195,224,0.25); background:#FFFFFF;" />
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:12px;">
                    <span style="font-size:22px; font-weight:800; color:#FFFFFF; letter-spacing:-0.02em;">VitalUp Privacy Desk</span>
                    <span style="display:block; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.1em; color:#19C3E0; margin-top:3px;">Request Under Review</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:34px 28px 24px;">
              <h1 style="margin:0 0 14px; font-size:20px; font-weight:700; color:#FFFFFF; letter-spacing:-0.01em;">
                Account Deletion Request Received
              </h1>
              <p style="margin:0 0 20px; font-size:15px; line-height:1.65; color:#94A3B8;">
                Hi <strong style="color:#F1F5F9;">${safeName}</strong>,<br><br>
                We have received your request to delete the VitalUp account associated with <strong style="color:#19C3E0;">${safeEmail}</strong>.
              </p>
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(25,195,224,0.28); border-radius:14px; margin-bottom:22px; padding:18px;">
                <tr>
                  <td>
                    <span style="display:inline-block; padding:3px 10px; background:rgba(25,195,224,0.12); border:1px solid rgba(25,195,224,0.3); border-radius:999px; font-size:10px; font-weight:700; color:#19C3E0; text-transform:uppercase; letter-spacing:0.06em; margin-bottom:10px;">
                      72-HOUR PROCESSING WINDOW
                    </span>
                    <div style="font-size:15px; font-weight:700; color:#FFFFFF; margin-bottom:8px;">
                      Scope: ${safeScope}
                    </div>
                    <div style="font-size:13px; line-height:1.6; color:#94A3B8;">
                      Status: <strong>Verification in progress</strong>. To protect your data, requests are held for 72 hours before irreversible purging.
                    </div>
                  </td>
                </tr>
              </table>
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="background-color:#162032; border:1px solid rgba(186,186,186,0.16); border-radius:14px; margin-bottom:24px;">
                <tr>
                  <td style="padding:16px 18px;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td width="36" valign="top" style="padding-right:12px;">
                          <div style="width:32px; height:32px; border-radius:8px; background:rgba(25,195,224,0.15); border:1px solid rgba(25,195,224,0.3); text-align:center; line-height:30px; font-size:15px;">
                            🛡️
                          </div>
                        </td>
                        <td valign="middle" style="font-size:13px; line-height:1.55; color:#E2E8F0;">
                          <strong>Made this request by mistake?</strong><br>
                          Simply reply directly to this email within 72 hours to cancel the deletion and keep your account active.
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              <p style="margin:0; font-size:13px; line-height:1.55; color:#64748B;">
                Note: Active Google Play or App Store subscriptions cannot be cancelled by developers and must be cancelled in your store account.
              </p>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:22px 24px; border-top:1px solid #1F293D; background-color:#0B0F19;">
              <p style="margin:0 0 8px; font-size:12px; color:#64748B;">
                Official Privacy Contact: <a href="mailto:privacy@vitalup.live" style="color:#19C3E0; text-decoration:none;">privacy@vitalup.live</a>
              </p>
              <p style="margin:0; font-size:11px; color:#475569;">
                &copy; 2026 VitalUp Platform &bull; <a href="https://vitalup.live/privacy" style="color:#64748B; text-decoration:none;">Privacy Policy</a> &bull; <a href="https://vitalup.live/terms" style="color:#64748B; text-decoration:none;">Terms</a>
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


