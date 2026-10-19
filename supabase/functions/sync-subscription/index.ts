// Refreshes the caller's VitalUp Pro status from RevenueCat right after a
// purchase or restore, so the server (AI quotas) agrees with the app without
// waiting for the webhook.
//
// POST (no body), with the user's JWT:
//   supabase.functions.invoke('sync-subscription')
// 200: { is_pro, expires_at, product_id, will_renew }
//
// The app's word is never taken: the status is read from RevenueCat's REST
// API (REVENUECAT_SECRET_API_KEY). A row updated in the last 15 s is
// returned as stored, and without the key the stored row is all there is.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { bearerToken, errorResponse, handleError, jsonResponse, requireMethod, UUID_RE } from "../_shared/validate.ts";
import { fetchProStatus, hasRevenueCatKey, type ProStatus, saveProStatus } from "../_shared/revenuecat.ts";

const MAX_BODY_BYTES = 4 * 1024;
const THROTTLE_MS = 15_000;

// deno-lint-ignore no-explicit-any
let serviceClient: any = null;

interface StoredRow {
  is_premium: boolean | null;
  expires_at: string | null;
  product_id: string | null;
  will_renew: boolean | null;
  updated_at: string | null;
}

function fromRow(row: StoredRow | null): ProStatus {
  if (!row) return { isPro: false, expiresAt: null, productId: null, willRenew: null };
  // Same rule as is_premium_user(): flagged and not past its expiry.
  const expired = row.expires_at !== null && Date.parse(row.expires_at) < Date.now();
  return {
    isPro: row.is_premium === true && !expired,
    expiresAt: row.expires_at,
    productId: row.product_id,
    willRenew: row.will_renew,
  };
}

function respond(status: ProStatus): Response {
  return jsonResponse({
    is_pro: status.isPro,
    expires_at: status.expiresAt,
    product_id: status.productId,
    will_renew: status.willRenew,
  });
}

serve(async (req) => {
  try {
    requireMethod(req, "POST");
    const declared = Number(req.headers.get("content-length") ?? "0");
    if (!Number.isFinite(declared) || declared > MAX_BODY_BYTES) return errorResponse(413, "Request is too large.");

    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) {
      console.error("sync-subscription: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
      return errorResponse(500, "Couldn't check your plan. Try again.");
    }
    serviceClient ??= createClient(url, serviceKey);
    const client = serviceClient;

    const token = bearerToken(req);
    if (!token) return errorResponse(401, "Not signed in", { code: "missing_token" });
    const { data: auth, error: authError } = await client.auth.getUser(token);
    const userId: string | undefined = auth?.user?.id;
    if (authError || !userId || !UUID_RE.test(userId)) {
      return errorResponse(401, "Not signed in", { code: "invalid_session" });
    }

    const { data: row, error: readError } = await client
      .from("subscriptions")
      .select("is_premium, expires_at, product_id, will_renew, updated_at")
      .eq("user_id", userId)
      .maybeSingle();
    if (readError) {
      console.error("sync-subscription: read failed", readError.code);
      return errorResponse(500, "Couldn't check your plan. Try again.");
    }
    const stored = row as StoredRow | null;

    if (!hasRevenueCatKey()) return respond(fromRow(stored));
    const updatedAt = stored?.updated_at ? Date.parse(stored.updated_at) : NaN;
    if (Number.isFinite(updatedAt) && Date.now() - updatedAt < THROTTLE_MS) return respond(fromRow(stored));

    let status: ProStatus;
    try {
      status = await fetchProStatus(userId);
    } catch (e) {
      console.error("sync-subscription: RevenueCat lookup failed", e);
      return errorResponse(503, "Couldn't check your plan. Try again.");
    }
    // Nothing bought and nothing stored: no row to write.
    if (status.isPro || stored) await saveProStatus(client, userId, status);
    return respond(status);
  } catch (e) {
    return handleError(e, "sync-subscription");
  }
});
