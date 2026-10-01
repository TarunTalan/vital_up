// Per-user daily fair-use quota for AI-backed features, backed by the
// consume_ai_quota / refund_ai_quota SQL functions (service role only).
//
// Fails open: if the quota check itself errors (DB hiccup, migration not yet
// applied) the request is allowed and the error logged. The cap protects the
// shared provider quota; it should never be the reason a scan fails.

// deno-lint-ignore no-explicit-any
type Client = any;

export type AiFeature = 'photo_scan' | 'diet_plan' | 'vita_chat' | 'vita_insights';

export interface QuotaResult {
  allowed: boolean;
  /** Uses left today after this one; -1 = unlimited; null = unknown. */
  remaining: number | null;
  limit: number;
}

export function dailyLimit(envKey: string, fallback: number): number {
  const parsed = parseInt(Deno.env.get(envKey) ?? '', 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

export async function consumeDailyQuota(
  serviceClient: Client,
  userId: string,
  feature: AiFeature,
  limit: number,
): Promise<QuotaResult> {
  try {
    const { data, error } = await serviceClient.rpc('consume_ai_quota', {
      p_user_id: userId,
      p_feature: feature,
      p_daily_limit: limit,
    });
    if (error) {
      console.error(`Quota check for ${feature} failed (allowing request): ${error.message}`);
      return { allowed: true, remaining: null, limit };
    }
    if (data === null || data === undefined) return { allowed: false, remaining: 0, limit };
    return { allowed: true, remaining: Number(data), limit };
  } catch (e) {
    console.error(`Quota check for ${feature} threw (allowing request):`, e);
    return { allowed: true, remaining: null, limit };
  }
}

export async function refundDailyQuota(serviceClient: Client, userId: string, feature: AiFeature): Promise<void> {
  const { error } = await serviceClient.rpc('refund_ai_quota', { p_user_id: userId, p_feature: feature });
  if (error) console.error(`Quota refund for ${feature} failed: ${error.message}`);
}
