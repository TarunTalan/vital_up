/// Daily AI allowances shown on the paywall, free vs Pro.
///
/// The server enforces the real numbers: keep these in step with the
/// defaults in `supabase/functions/_shared/quota.ts` callers (scan-food,
/// vita-chat, generate-diet-plan) and `get_remaining_scans`. Pro limits are
/// fair-use caps, so the app says "up to", never "unlimited".
class ProLimit {
  final String label;
  final int free;
  final int pro;

  const ProLimit(this.label, {required this.free, required this.pro});
}

abstract final class ProLimits {
  static const photoScans = ProLimit('Photo food scans', free: 5, pro: 100);
  static const vitaChats = ProLimit('Vita chat messages', free: 15, pro: 150);
  static const dietPlans = ProLimit('AI diet plans', free: 3, pro: 20);
  static const insights = ProLimit('Vita insights', free: 3, pro: 20);

  static const all = [photoScans, vitaChats, dietPlans, insights];
}

/// Which daily limit sent the user to the paywall.
enum ProReason {
  photoScans(ProLimits.photoScans, "You've used today's free photo scans"),
  vitaChats(ProLimits.vitaChats, "You've used today's free Vita messages"),
  dietPlans(ProLimits.dietPlans, "You've used today's free diet plans"),
  insights(ProLimits.insights, "You've used today's free insights");

  final ProLimit limit;
  final String title;

  const ProReason(this.limit, this.title);
}
