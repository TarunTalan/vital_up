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

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

/** Tables keyed by the user that may not cascade from auth.users. */
const USER_TABLES: Array<{ table: string; column: string }> = [
  { table: "user_health_data", column: "user_id" },
  { table: "profiles", column: "id" },
];

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

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
      .remove(data.map((f) => `${folder}/${f.name}`));
    if (removeError) throw removeError;
  }
}

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: auth, error: authError } = await admin.auth.getUser(jwt);
  if (authError || !auth.user) return json({ error: "Not signed in" }, 401);
  const userId = auth.user.id;

  try {
    await removeFolder("avatars", userId);

    for (const { table, column } of USER_TABLES) {
      const { error } = await admin.from(table).delete().eq(column, userId);
      // A missing table is fine; anything else stops the deletion.
      if (error && error.code !== "42P01") throw error;
    }

    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  } catch (e) {
    console.error(`delete-account failed for ${userId}:`, e);
    return json({ error: "Could not delete the account. Try again." }, 500);
  }

  return json({ deleted: true });
});
