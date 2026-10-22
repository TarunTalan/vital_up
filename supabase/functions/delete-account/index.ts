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
// 4. Deletes the RevenueCat customer (purchase history), best effort.
//
// An active App Store / Play subscription is NOT cancelled by this; the app
// tells the user to cancel it in their store account.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { bearerToken, errorResponse, jsonResponse, UUID_RE } from "../_shared/validate.ts";
import { deleteRevenueCatCustomer } from "../_shared/revenuecat.ts";
import { PRIVACY_EMAIL, SUPPORT_EMAIL } from "../_shared/email.ts";
import {
  renderAdminDeletionNotice,
  renderDeletionConfirmed,
  type UserDeletionDetails,
} from "./templates.ts";

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

async function sendResend(body: Record<string, unknown>): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}`);
}

async function sendDeletionConfirmedEmail(details: UserDeletionDetails): Promise<void> {
  const { userEmail, userName } = details;
  if (!RESEND_API_KEY || !userEmail) return;
  const deletedAt = new Date();

  // 1. Confirmation to the user
  await sendResend({
    from: SENDER_EMAIL,
    to: [userEmail],
    reply_to: SUPPORT_EMAIL,
    subject: "Your VitalUp account has been deleted",
    ...renderDeletionConfirmed(details, deletedAt),
  }).catch((err) => console.error("Failed to send user deletion email:", err));

  // 2. Audit note to the privacy and support desks
  await sendResend({
    from: "VitalUp Audit <privacy@vitalup.live>",
    to: [PRIVACY_EMAIL, SUPPORT_EMAIL],
    reply_to: userEmail,
    subject: `[Audit · Account deleted] ${userEmail} (${userName || details.username || "User"})`,
    ...renderAdminDeletionNotice(details, deletedAt),
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

    // The account is gone either way; a RevenueCat failure is only logged.
    try {
      await deleteRevenueCatCustomer(userId);
    } catch (rcErr) {
      console.error("delete-account: RevenueCat customer not deleted:", rcErr);
    }

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
