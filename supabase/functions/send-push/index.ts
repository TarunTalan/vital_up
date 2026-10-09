// Sends one `notifications` row to the user's devices through FCM HTTP v1.
//
// Called by the `notifications_dispatch_push` trigger (pg_net):
//   POST { record: <notifications row> }   header x-push-secret: PUSH_WEBHOOK_SECRET
//
// Secrets:
//   FIREBASE_SERVICE_ACCOUNT  the service-account JSON from Firebase console →
//                             Project settings → Service accounts
//   PUSH_WEBHOOK_SECRET       must match the `push_webhook_secret` vault secret
//
// Deploy with --no-verify-jwt (the trigger has no user JWT; the shared secret
// authenticates it instead).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  cleanText,
  errorResponse,
  handleError,
  HttpError,
  isObject,
  jsonResponse,
  KB,
  readJsonBody,
  requireMethod,
  timingSafeEqual,
  UUID_RE,
} from "../_shared/validate.ts";

interface NotificationRow {
  id: number;
  user_id: string;
  type: string;
  title: string;
  body: string | null;
  data: Record<string, unknown> | null;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

const WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const serviceAccount = parseServiceAccount(Deno.env.get("FIREBASE_SERVICE_ACCOUNT"));

/** A malformed secret must not crash the function at boot. */
function parseServiceAccount(raw: string | undefined): ServiceAccount | null {
  try {
    const sa = JSON.parse(raw ?? "");
    if (
      typeof sa?.project_id === "string" && /^[a-z0-9-]{1,64}$/.test(sa.project_id) &&
      typeof sa.client_email === "string" && typeof sa.private_key === "string"
    ) {
      return sa as ServiceAccount;
    }
  } catch { /* handled below */ }
  console.error("send-push: FIREBASE_SERVICE_ACCOUNT is missing or invalid");
  return null;
}

const MAX_BODY = 32 * KB;
const FETCH_TIMEOUT_MS = 10_000;
/** A user rarely has more than a handful of devices; cap fan-out anyway. */
const MAX_TOKENS = 20;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function fetchWithTimeout(url: string, init: RequestInit): Promise<Response> {
  return fetch(url, { ...init, signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
}

/** The webhook body's `record`, validated and trimmed to FCM-safe sizes. */
function parseRecord(body: Record<string, unknown>): NotificationRow {
  const r = body.record;
  if (!isObject(r)) throw new HttpError(400, "Missing record.");
  const id = r.id;
  if (typeof id !== "number" || !Number.isSafeInteger(id) || id < 0) {
    throw new HttpError(400, "Invalid record.");
  }
  if (typeof r.user_id !== "string" || !UUID_RE.test(r.user_id)) {
    throw new HttpError(400, "Invalid record.");
  }
  const title = cleanText(r.title, 120);
  if (!title) throw new HttpError(400, "Invalid record.");
  return {
    id,
    user_id: r.user_id,
    type: cleanText(r.type, 40),
    title,
    body: cleanText(r.body, 500, { multiline: true }) || null,
    data: isObject(r.data) ? r.data : null,
  };
}

function base64Url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Google access tokens last an hour; reuse one while the instance is warm.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function googleAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;

  const pem = serviceAccount.private_key
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );

  const res = await fetchWithTimeout("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64Url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`Google token request failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  if (typeof json?.access_token !== "string") throw new Error("Google token response had no token");
  const lifetime = typeof json.expires_in === "number" ? json.expires_in : 3600;
  cachedToken = { value: json.access_token, expiresAt: now + lifetime };
  return cachedToken.value;
}

/** Sends to one device. Returns false when FCM says the token is dead. */
async function sendToToken(
  serviceAccount: ServiceAccount,
  accessToken: string,
  token: string,
  n: NotificationRow,
): Promise<boolean> {
  // Routes are app route names; anything else is dropped.
  const rawRoute = n.data?.route;
  const route = typeof rawRoute === "string" && /^[a-z0-9-]{1,40}$/.test(rawRoute) ? rawRoute : "";
  let res: Response;
  try {
    res = await fetchWithTimeout(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: n.title, body: n.body ?? "" },
          // FCM data values must be strings.
          data: { notification_id: String(n.id), type: n.type, route },
          android: {
            priority: "high",
            notification: { channel_id: "vitalup_general", tag: `notification-${n.id}` },
          },
        },
      }),
    },
  );
  } catch (e) {
    console.error("FCM send failed (network):", e);
    return true; // Keep the token; it may be fine next time.
  }
  if (res.ok) return true;

  const text = await res.text();
  if (res.status === 404 || text.includes("UNREGISTERED")) {
    return false;
  }
  console.error(`FCM send failed (${res.status}): ${text}`);
  return true;
}

serve(async (req) => {
  try {
    requireMethod(req, "POST");
    if (!WEBHOOK_SECRET || !timingSafeEqual(req.headers.get("x-push-secret") ?? "", WEBHOOK_SECRET)) {
      return errorResponse(401, "Unauthorized.");
    }
    if (!serviceAccount) return errorResponse(503, "Push is not configured.");

    const record = parseRecord(await readJsonBody(req, MAX_BODY));

    const { data: tokens, error } = await supabase
      .from("push_tokens")
      .select("token")
      .eq("user_id", record.user_id)
      .limit(MAX_TOKENS);
    if (error) throw error;
    const valid = (tokens ?? [])
      .map((t: { token?: unknown }) => t.token)
      .filter((t: unknown): t is string => typeof t === "string" && t.length > 0 && t.length <= 4096);
    if (!valid.length) return jsonResponse({ sent: 0 });

    const accessToken = await googleAccessToken(serviceAccount);
    const results = await Promise.all(
      valid.map(async (token: string) => ({
        token,
        alive: await sendToToken(serviceAccount, accessToken, token, record),
      })),
    );

    const dead = results.filter((r) => !r.alive).map((r) => r.token);
    if (dead.length) await supabase.from("push_tokens").delete().in("token", dead);

    return jsonResponse({ sent: results.length - dead.length, removed: dead.length });
  } catch (e) {
    return handleError(e, "send-push");
  }
});
