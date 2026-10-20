// Per-user daily fair-use quota for AI-backed features, backed by the
// consume_ai_quota / refund_ai_quota SQL functions (service role only).
//
// Fails closed: if the quota check itself errors, the request is refused.
// Failing open let anyone who could make the check error (or wait for a DB
// hiccup) spend the shared provider quota without limit.
//
// Pro users get a higher fair-use cap ([proLimit]) instead of no cap, so one
// account can't spend the whole provider budget.

// deno-lint-ignore no-explicit-any
type Client = any;

export type AiFeature = 'photo_scan' | 'diet_plan' | 'vita_chat' | 'vita_insights' | 'nutrition_lookup';

export interface QuotaResult {
  allowed: boolean;
  /** Uses left today after this one; -1 = unlimited; null = unknown. */
  remaining: number | null;
  /** The cap that applied (the Pro cap for Pro users when known). */
  limit: number;
  /** Whether the user has Pro; null when it couldn't be checked. */
  pro: boolean | null;
}

export function dailyLimit(envKey: string, fallback: number): number {
  const parsed = parseInt(Deno.env.get(envKey) ?? '', 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

/** Whether the user has Pro; null when the check failed. */
export async function isProUser(serviceClient: Client, userId: string): Promise<boolean | null> {
  try {
    const { data, error } = await serviceClient.rpc('is_premium_user', { p_user_id: userId });
    if (error) return null;
    return data === true;
  } catch (_) {
    return null;
  }
}

export async function consumeDailyQuota(
  serviceClient: Client,
  userId: string,
  feature: AiFeature,
  limit: number,
  proLimit?: number,
): Promise<QuotaResult> {
  try {
    const params: Record<string, unknown> = {
      p_user_id: userId,
      p_feature: feature,
      p_daily_limit: limit,
    };
    if (proLimit !== undefined) params.p_pro_limit = proLimit;
    const { data, error } = await serviceClient.rpc('consume_ai_quota', params);
    if (error) {
      console.error(`Quota check for ${feature} failed (refusing request): ${error.message}`);
      return { allowed: false, remaining: null, limit, pro: null };
    }
    if (data === null || data === undefined) {
      // Refused: only now is it worth a second query to tell the client
      // whether upgrading would help.
      const pro = await isProUser(serviceClient, userId);
      return { allowed: false, remaining: 0, limit: pro && proLimit !== undefined ? proLimit : limit, pro };
    }
    return { allowed: true, remaining: Number(data), limit, pro: null };
  } catch (e) {
    console.error(`Quota check for ${feature} threw (refusing request):`, e);
    return { allowed: false, remaining: null, limit, pro: null };
  }
}

/** Extra fields for a 429 body: whether the user has Pro and if Pro would help. */
export function quotaUpgradeInfo(quota: QuotaResult): { pro: boolean; upgradable: boolean } {
  const pro = quota.pro === true;
  return { pro, upgradable: quota.pro === false };
}

export async function refundDailyQuota(serviceClient: Client, userId: string, feature: AiFeature): Promise<void> {
  const { error } = await serviceClient.rpc('refund_ai_quota', { p_user_id: userId, p_feature: feature });
  if (error) console.error(`Quota refund for ${feature} failed: ${error.message}`);
}

/**
 * Per-minute cap on top of the daily one, so a script can't spend a whole
 * day's allowance (and the shared provider rate limit) in a few seconds.
 * Backed by ai_burst_allowed (20261028_ai_burst_limit.sql).
 *
 * Fails open: the daily quota above already fails closed and bounds the
 * spend, so a broken burst check (or the migration not pushed yet) only
 * loses the smoothing, not the cap.
 */
export async function burstAllowed(
  serviceClient: Client,
  userId: string,
  feature: AiFeature,
  maxPerMinute: number,
): Promise<boolean> {
  try {
    const { data, error } = await serviceClient.rpc('ai_burst_allowed', {
      p_user_id: userId,
      p_feature: feature,
      p_max: maxPerMinute,
    });
    if (error) {
      console.error(`Burst check for ${feature} failed (allowing): ${error.message}`);
      return true;
    }
    return data !== false;
  } catch (e) {
    console.error(`Burst check for ${feature} threw (allowing):`, e);
    return true;
  }
}
