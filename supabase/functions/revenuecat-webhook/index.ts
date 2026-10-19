// RevenueCat webhook: keeps `subscriptions` in sync with store purchases.
//
// Auth (fails closed when REVENUECAT_WEBHOOK_SECRET is unset):
//   - `Authorization: Bearer <secret>` (or the raw secret), the value set in
//     RevenueCat's webhook settings; or
//   - `X-RevenueCat-Webhook-Signature`: base64 HMAC-SHA256 of the raw body.
// Both are compared in constant time.
//
// With REVENUECAT_SECRET_API_KEY set, an event only says "this customer
// changed": the current entitlement is read from RevenueCat's REST API, so
// late, repeated or out-of-order events can't leave a wrong answer. Without
// the key the event itself is applied, ignoring events older than the last
// one saved. CANCELLATION means auto-renew was switched off: Pro stays until
// the paid period (or a billing grace period) ends.
//
// The app user id in RevenueCat must be the Supabase user id (a UUID).
// Events for other ids are acknowledged (200) and logged, so RevenueCat does
// not retry them forever.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
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
import { fetchProStatus, hasRevenueCatKey, PRO_ENTITLEMENT, type ProStatus, saveProStatus } from "../_shared/revenuecat.ts";

const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
const MAX_BODY = 64 * KB;

/** Events after which the entitlement lasts until expiration_at_ms. */
const ACTIVE_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  // Auto-renew switched off: still paid up until expiration.
  "CANCELLATION",
  // Payment failing: the store's grace period is in expiration_at_ms.
  "BILLING_ISSUE",
]);
const ENDED_EVENTS = new Set(["EXPIRATION", "SUBSCRIPTION_PAUSED"]);
/** Events whose customer is re-read when the REST API is available. */
const LOOKUP_EVENTS = new Set([...ACTIVE_EVENTS, ...ENDED_EVENTS, "TRANSFER", "SUBSCRIPTION_EXTENDED", "TEMPORARY_ENTITLEMENT_GRANT", "REFUND_REVERSED"]);

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

function uuidsIn(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((v): v is string => typeof v === "string" && UUID_RE.test(v));
}

/** Whether the event concerns the Pro entitlement (true when it doesn't say). */
function concernsPro(event: Record<string, unknown>): boolean {
  const ids = event.entitlement_ids;
  if (Array.isArray(ids)) return ids.includes(PRO_ENTITLEMENT);
  const single = event.entitlement_id;
  if (typeof single === "string") return single === PRO_ENTITLEMENT;
  return true;
}

serve(async (req) => {
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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // RevenueCat sends app_user_id at the top level of `event`; older
    // payloads nest original_app_user_id in customer_info.
    const customer = isObject(event.customer_info) ? event.customer_info : {};
    const appUserId = shortString(event.app_user_id, 128) ??
      shortString(event.original_app_user_id, 128) ??
      shortString(customer.original_app_user_id, 128);
    const eventAt = isoDate(event.event_timestamp_ms);

    if (hasRevenueCatKey()) {
      if (!LOOKUP_EVENTS.has(type)) {
        console.log(`revenuecat-webhook: ignoring event type ${type}`);
        return jsonResponse({ success: true });
      }
      // A transfer moves purchases between app user ids: re-read both sides.
      const ids = new Set<string>();
      if (appUserId && UUID_RE.test(appUserId)) ids.add(appUserId);
      if (type === "TRANSFER") {
        for (const id of [...uuidsIn(event.transferred_from), ...uuidsIn(event.transferred_to)]) ids.add(id);
      }
      if (ids.size === 0) {
        console.error("revenuecat-webhook: event without a Supabase user id");
        return jsonResponse({ success: true, ignored: true });
      }
      try {
        for (const id of ids) {
          await saveProStatus(supabase, id, await fetchProStatus(id), eventAt);
        }
      } catch (e) {
        console.error("revenuecat-webhook: status refresh failed", e);
        // 5xx so RevenueCat retries later.
        return errorResponse(500, "Could not save the update.");
      }
      return jsonResponse({ success: true });
    }

    // Fallback without a REST key: apply the event itself.
    if (!ACTIVE_EVENTS.has(type) && !ENDED_EVENTS.has(type)) {
      console.log(`revenuecat-webhook: ignoring event type ${type}`);
      return jsonResponse({ success: true });
    }
    if (!concernsPro(event)) return jsonResponse({ success: true, ignored: true });
    if (!appUserId || !UUID_RE.test(appUserId)) {
      console.error("revenuecat-webhook: event without a Supabase user id");
      return jsonResponse({ success: true, ignored: true });
    }

    if (eventAt) {
      const { data: existing, error: readError } = await supabase
        .from("subscriptions")
        .select("last_event_at")
        .eq("user_id", appUserId)
        .maybeSingle();
      if (readError) {
        console.error("revenuecat-webhook: read failed", readError.code);
        return errorResponse(500, "Could not save the update.");
      }
      const last = existing?.last_event_at ? Date.parse(existing.last_event_at) : NaN;
      if (Number.isFinite(last) && last > Date.parse(eventAt)) {
        console.log(`revenuecat-webhook: ignoring out-of-order ${type}`);
        return jsonResponse({ success: true, ignored: true });
      }
    }

    const transaction = isObject(event.transaction) ? event.transaction : {};
    const productId = shortString(event.product_id, 200) ?? shortString(transaction.product_id, 200);
    const expiresAt = isoDate(event.expiration_at_ms) ?? isoDate(transaction.expires_date);
    const lifetime = type === "NON_RENEWING_PURCHASE" && expiresAt === null;
    const stillPaid = expiresAt !== null && Date.parse(expiresAt) > Date.now();
    const status: ProStatus = {
      isPro: ACTIVE_EVENTS.has(type) && (lifetime || stillPaid),
      expiresAt,
      productId,
      willRenew: type === "CANCELLATION" || type === "BILLING_ISSUE" || type === "NON_RENEWING_PURCHASE"
        ? false
        : ACTIVE_EVENTS.has(type),
    };
    try {
      await saveProStatus(supabase, appUserId, status, eventAt);
    } catch (e) {
      console.error("revenuecat-webhook: upsert failed", e);
      // 5xx so RevenueCat retries later.
      return errorResponse(500, "Could not save the update.");
    }

    return jsonResponse({ success: true });
  } catch (e) {
    return handleError(e, "revenuecat-webhook");
  }
});
