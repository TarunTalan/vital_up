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
const serviceAccount: ServiceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}

function base64Url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Google access tokens last an hour; reuse one while the instance is warm.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function googleAccessToken(): Promise<string> {
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

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64Url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`Google token request failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  cachedToken = { value: json.access_token, expiresAt: now + (json.expires_in ?? 3600) };
  return cachedToken.value;
}

/** Sends to one device. Returns false when FCM says the token is dead. */
async function sendToToken(accessToken: string, token: string, n: NotificationRow): Promise<boolean> {
  const route = typeof n.data?.route === "string" ? n.data.route : "";
  const res = await fetch(
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
  if (res.ok) return true;

  const text = await res.text();
  if (res.status === 404 || text.includes("UNREGISTERED")) {
    return false;
  }
  console.error(`FCM send failed (${res.status}): ${text}`);
  return true;
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!WEBHOOK_SECRET || !timingSafeEqual(req.headers.get("x-push-secret") ?? "", WEBHOOK_SECRET)) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (!serviceAccount.project_id) {
    return new Response("FIREBASE_SERVICE_ACCOUNT is not set", { status: 500 });
  }

  try {
    const { record } = await req.json() as { record?: NotificationRow };
    if (!record?.user_id) return new Response("Missing record", { status: 400 });

    const { data: tokens, error } = await supabase
      .from("push_tokens")
      .select("token")
      .eq("user_id", record.user_id);
    if (error) throw error;
    if (!tokens?.length) return Response.json({ sent: 0 });

    const accessToken = await googleAccessToken();
    const results = await Promise.all(
      tokens.map(async ({ token }) => ({ token, alive: await sendToToken(accessToken, token, record) })),
    );

    const dead = results.filter((r) => !r.alive).map((r) => r.token);
    if (dead.length) await supabase.from("push_tokens").delete().in("token", dead);

    return Response.json({ sent: results.length - dead.length, removed: dead.length });
  } catch (e) {
    console.error("send-push error:", e);
    return new Response("Internal error", { status: 500 });
  }
});
