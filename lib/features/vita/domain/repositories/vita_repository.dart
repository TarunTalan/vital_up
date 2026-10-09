import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';

/// Thrown when Vita can't produce a reply; [message] is user-facing.
class VitaException implements Exception {
  final String message;
  final bool offline;
  final bool dailyLimit;

  const VitaException(
    this.message, {
    this.offline = false,
    this.dailyLimit = false,
  });

  // Short user-facing messages (no technical detail; that goes to logs).
  static const couldNotReply = "Vita couldn't reply. Try again.";
  static const signIn = 'Sign in to chat with Vita.';
  static const sessionExpired = 'Your session expired. Sign in again.';
  static const dailyLimitReached = "You've hit today's Vita limit. Try tomorrow.";
  static const tooSlow = 'Vita is taking too long. Try again.';
  static const offlineMessage = "You're offline. Try again when connected.";

  @override
  String toString() => message;
}

/// Vita's coaching content: on-device chat history, AI replies, and
/// cross-feature insights built from the user's real health data.
abstract class VitaRepository {
  /// Saved conversation (stored on device), starting with Vita's greeting.
  Future<List<VitaMessage>> loadHistory();

  Future<void> saveHistory(List<VitaMessage> messages);

  /// Vita's answer to the latest user message in [history].
  /// [draftPlan] replaces the active plan in Vita's context when the user is
  /// tweaking a plan they haven't saved yet. Throws [VitaException].
  Future<VitaMessage> reply(List<VitaMessage> history, {MealPlan? draftPlan});

  /// Rows computed on device from real data (works offline).
  Future<HealthAnalysis> getHealthAnalysis();

  /// Today's score computed on device (works offline).
  Future<StressReport> getStressReport();

  /// One check-in per day; logging again today replaces it.
  Future<void> saveStressCheckIn(int level, {List<StressTag> tags = const []});

  /// Saved check-ins (last 90 days), oldest first.
  List<StressCheckIn> getStressCheckIns();

  /// Asks for Health Connect / Apple Health heart data permissions.
  Future<bool> connectWearable();

  /// AI headline / stress tip / diet note, fetched at most once a day and
  /// cached; returns the last cached copy (or null) when offline.
  Future<VitaDailyInsights?> getDailyInsights();

  /// Reloads local cache from disk (e.g. after background widget writes).
  Future<void> reload();
}
