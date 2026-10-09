// RevenueCat webhook: keeps `subscriptions` in sync with store purchases.
//
// Auth (fails closed when REVENUECAT_WEBHOOK_SECRET is unset):
//   - `Authorization: Bearer <secret>` (or the raw secret), the value set in
//     RevenueCat's webhook settings; or
//   - `X-RevenueCat-Webhook-Signature`: base64 HMAC-SHA256 of the raw body.
// Both are compared in constant time.
//
// The app user id in RevenueCat must be the Supabase user id (a UUID).
// Events for other ids are acknowledged (200) and logged, so RevenueCat does
// not retry them forever.

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import {
  errorResponse,
  handleError,
  HttpError,
  isObject,
  jsonResponse,
  KB,
  parseJsonObject,
  readTextBody,
  requireMethod,
  timingSafeEqual,
  UUID_RE,
} from "../_shared/validate.ts";

const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
const MAX_BODY = 64 * KB;

const PREMIUM_EVENTS = new Set(["INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION"]);
const ENDED_EVENTS = new Set([
  "CANCELLATION",
  "EXPIRATION",
  "REFUND",
  "REFUND_REQUESTED",
  "SUBSCRIPTION_PAUSED",
]);

async function hmacBase64(payload: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)));
  let raw = "";
  for (const b of sig) raw += String.fromCharCode(b);
  return btoa(raw);
}

async function isAuthorized(req: Request, payload: string): Promise<boolean> {
  const auth = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (auth && timingSafeEqual(auth, WEBHOOK_SECRET)) return true;
  const signature = req.headers.get("x-revenuecat-webhook-signature")?.trim();
  if (signature) return timingSafeEqual(signature, await hmacBase64(payload, WEBHOOK_SECRET));
  return false;
}

/** ISO date string or epoch millis to ISO; null when missing or invalid. */
function isoDate(value: unknown): string | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  }
  if (typeof value === "string" && value.length <= 64) {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  }
  return null;
}

function shortString(value: unknown, max: number): string | null {
  return typeof value === "string" && value.length > 0 && value.length <= max ? value : null;
}

Deno.serve(async (req) => {
  try {
    requireMethod(req, "POST");
    if (!WEBHOOK_SECRET) {
      console.error("revenuecat-webhook: REVENUECAT_WEBHOOK_SECRET is not set");
      return errorResponse(503, "Not configured.");
    }

    const payload = await readTextBody(req, MAX_BODY);
    if (!(await isAuthorized(req, payload))) {
      return errorResponse(401, "Unauthorized.");
    }

    const body = parseJsonObject(payload);
    const event = body.event;
    if (!isObject(event)) throw new HttpError(400, "Missing event.");

    const type = shortString(event.type, 64);
    if (!type) throw new HttpError(400, "Missing event type.");
    if (type === "TEST") return jsonResponse({ success: true });
    if (!PREMIUM_EVENTS.has(type) && !ENDED_EVENTS.has(type)) {
      console.log(`revenuecat-webhook: ignoring event type ${type}`);
      return jsonResponse({ success: true });
    }

    // RevenueCat sends app_user_id at the top level of `event`; older
    // payloads nest original_app_user_id in customer_info.
    const customer = isObject(event.customer_info) ? event.customer_info : {};
    const appUserId = shortString(event.app_user_id, 128) ??
      shortString(event.original_app_user_id, 128) ??
      shortString(customer.original_app_user_id, 128);
    if (!appUserId || !UUID_RE.test(appUserId)) {
      console.error("revenuecat-webhook: event without a Supabase user id");
      return jsonResponse({ success: true, ignored: true });
    }

    const transaction = isObject(event.transaction) ? event.transaction : {};
    const productId = shortString(event.product_id, 200) ?? shortString(transaction.product_id, 200);
    const expires = isoDate(event.expiration_at_ms) ?? isoDate(transaction.expires_date);
    const isPremium = PREMIUM_EVENTS.has(type);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );
    const { error } = await supabase.from("subscriptions").upsert(
      {
        user_id: appUserId,
        is_premium: isPremium,
        product_id: productId,
        expires_at: isPremium ? expires : (expires ?? new Date().toISOString()),
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" },
    );
    if (error) {
      console.error("revenuecat-webhook: upsert failed", error);
      // 5xx so RevenueCat retries later.
      return errorResponse(500, "Could not save the update.");
    }

    return jsonResponse({ success: true });
  } catch (e) {
    return handleError(e, "revenuecat-webhook");
  }
});
