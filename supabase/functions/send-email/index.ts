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
import { authEmailKind, escapeHtml, renderAuthEmail } from "../_shared/email.ts";
import {
  renderDeletionAdmin,
  renderDeletionReceipt,
  renderSupportConfirmation,
  renderSupportTicket,
} from "./templates.ts";

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
      const { subject, html, text } = renderAuthEmail(authEmailKind(email_action_type), code);

      await dispatchResend({
        from: SENDER_EMAIL,
        reply_to: REPLY_TO_EMAIL,
        to: [recipient],
        subject,
        html,
        text,
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
        subject: `[Support · ${catLabel}] ${subj}`,
        ...renderSupportTicket({
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
      });

      await dispatchResend({
        from: SUPPORT_SENDER,
        to: [userEmail],
        reply_to: REPLY_TO_EMAIL,
        subject: `We received your request: ${subj}`,
        ...renderSupportConfirmation({
          user_name: userName,
          category: catLabel,
          subject: subj,
          description: desc,
        }),
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
        subject: `[Action required · Deletion request] ${userEmail}`,
        ...renderDeletionAdmin({
          user_email: userEmail,
          scope,
          description: desc,
          created_at: createdAt,
        }),
      });

      await dispatchResend({
        from: PRIVACY_SENDER,
        to: [userEmail],
        reply_to: PRIVACY_EMAIL,
        subject: "We received your account deletion request",
        ...renderDeletionReceipt({ user_email: userEmail, scope }),
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
