// RevenueCat REST API helpers: the source of truth for VitalUp Pro.
//
// Webhook events can arrive late, twice or out of order, so with a secret
// API key (REVENUECAT_SECRET_API_KEY) the webhook and sync-subscription ask
// RevenueCat for the customer's current entitlement instead of trusting an
// event. The app user id in RevenueCat is the Supabase user id.

// deno-lint-ignore no-explicit-any
type Client = any;

const API = "https://api.revenuecat.com/v1/subscribers/";
const TIMEOUT_MS = 8000;

export const REVENUECAT_SECRET_API_KEY = Deno.env.get("REVENUECAT_SECRET_API_KEY") ?? "";
export const PRO_ENTITLEMENT = (Deno.env.get("REVENUECAT_ENTITLEMENT_ID") ?? "").trim() || "pro";

export interface ProStatus {
  isPro: boolean;
  /** ISO time; null for a lifetime purchase or no entitlement. */
  expiresAt: string | null;
  productId: string | null;
  /** null when unknown (no subscription, or a one-time purchase). */
  willRenew: boolean | null;
}

export function hasRevenueCatKey(): boolean {
  return REVENUECAT_SECRET_API_KEY.length > 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseTime(value: unknown): number | null {
  if (typeof value !== "string" || value.length > 64) return null;
  const t = Date.parse(value);
  return Number.isNaN(t) ? null : t;
}

function shortString(value: unknown, max: number): string | null {
  return typeof value === "string" && value.length > 0 && value.length <= max ? value : null;
}

async function call(method: "GET" | "DELETE", appUserId: string): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    return await fetch(API + encodeURIComponent(appUserId), {
      method,
      headers: {
        Authorization: `Bearer ${REVENUECAT_SECRET_API_KEY}`,
        "Content-Type": "application/json",
      },
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

/** Reads the Pro entitlement from a `GET /v1/subscribers/{id}` body. */
export function proStatusFromSubscriber(body: unknown, now = Date.now()): ProStatus {
  const none: ProStatus = { isPro: false, expiresAt: null, productId: null, willRenew: null };
  const subscriber = isRecord(body) && isRecord(body.subscriber) ? body.subscriber : null;
  if (!subscriber) return none;
  const entitlements = isRecord(subscriber.entitlements) ? subscriber.entitlements : {};
  const entitlement = entitlements[PRO_ENTITLEMENT];
  if (!isRecord(entitlement)) return none;

  const productId = shortString(entitlement.product_identifier, 200);
  const expiresRaw = entitlement.expires_date;
  const expires = parseTime(expiresRaw);
  const grace = parseTime(entitlement.grace_period_expires_date);
  const lifetime = expiresRaw === null || expiresRaw === undefined;
  const isPro = lifetime || (expires !== null && expires > now) || (grace !== null && grace > now);

  let willRenew: boolean | null = null;
  const subscriptions = isRecord(subscriber.subscriptions) ? subscriber.subscriptions : {};
  const sub = productId ? subscriptions[productId] : undefined;
  if (isRecord(sub)) {
    willRenew = sub.unsubscribe_detected_at == null && sub.billing_issues_detected_at == null;
  }

  // During a grace period the paid-through date has passed: report the
  // grace end so the server keeps Pro until then.
  const shownExpiry = lifetime ? null : Math.max(expires ?? 0, grace ?? 0);
  return {
    isPro,
    expiresAt: shownExpiry ? new Date(shownExpiry).toISOString() : null,
    productId,
    willRenew,
  };
}

/** The customer's current Pro status from RevenueCat. Throws on failure. */
export async function fetchProStatus(appUserId: string): Promise<ProStatus> {
  if (!hasRevenueCatKey()) throw new Error("REVENUECAT_SECRET_API_KEY is not set");
  const res = await call("GET", appUserId);
  if (!res.ok) {
    await res.body?.cancel();
    throw new Error(`RevenueCat subscriber lookup failed: ${res.status}`);
  }
  return proStatusFromSubscriber(await res.json());
}

/** Upserts the user's `subscriptions` row. Throws on a database error. */
export async function saveProStatus(
  serviceClient: Client,
  userId: string,
  status: ProStatus,
  eventAt?: string | null,
): Promise<void> {
  const row: Record<string, unknown> = {
    user_id: userId,
    is_premium: status.isPro,
    product_id: status.productId,
    // An ended plan gets a past expiry so is_premium_user can't revive it.
    expires_at: status.isPro ? status.expiresAt : (status.expiresAt ?? new Date().toISOString()),
    will_renew: status.isPro ? status.willRenew : false,
    source: "revenuecat",
    updated_at: new Date().toISOString(),
  };
  if (eventAt) row.last_event_at = eventAt;
  const { error } = await serviceClient.from("subscriptions").upsert(row, { onConflict: "user_id" });
  if (error) throw new Error(`subscriptions upsert failed: ${error.code ?? error.message}`);
}

/**
 * Deletes the customer and their purchase history from RevenueCat (account
 * deletion). It does not cancel a store subscription. No-op without a key.
 */
export async function deleteRevenueCatCustomer(appUserId: string): Promise<void> {
  if (!hasRevenueCatKey()) return;
  const res = await call("DELETE", appUserId);
  await res.body?.cancel();
  // 404: RevenueCat never saw this user (no purchase screen opened).
  if (!res.ok && res.status !== 404) throw new Error(`RevenueCat delete failed: ${res.status}`);
}
