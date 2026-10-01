import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/vita/data/datasources/vita_local_datasource.dart';
import 'package:vital_up/features/vita/data/datasources/vita_remote_datasource.dart';
import 'package:vital_up/features/vita/data/services/health_snapshot_builder.dart';
import 'package:vital_up/features/vita/data/services/health_vitals_service.dart';
import 'package:vital_up/features/vita/domain/entities/health_snapshot.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/domain/services/health_analysis_builder.dart';
import 'package:vital_up/features/vita/domain/services/stress_estimator.dart';
import 'package:vital_up/core/events/habit_events.dart';

class VitaRepositoryImpl implements VitaRepository {
  final VitaRemoteDataSource _remote;
  final VitaLocalDataSource _local;
  final HealthSnapshotBuilder _snapshots;
  final HealthVitalsService _vitals;
  final SupabaseClient _supabase;
  final StressEstimator _stress;
  final HealthAnalysisBuilder _analysis;
  final HabitEvents? _events;

  /// Shared by screens opened together so the day's insights are fetched once.
  Future<VitaDailyInsights?>? _insightsInFlight;

  VitaRepositoryImpl({
    required this._remote,
    required this._local,
    required this._snapshots,
    required this._vitals,
    required this._supabase,
    this._stress = const StressEstimator(),
    this._analysis = const HealthAnalysisBuilder(),
    this._events,
  });

  String get _userId => _supabase.auth.currentUser?.id ?? 'guest';

  VitaMessage _greeting() => VitaMessage(
        sender: VitaSender.vita,
        sentAt: DateTime.now(),
        text: "Hey! I'm Vita 👋 Your personal health companion inside "
            "VitalUp. I'm connected to your health data — diet, sleep, "
            "stress, activity, and more. What's on your mind today?",
      );

  // --- Chat -----------------------------------------------------------------

  @override
  Future<List<VitaMessage>> loadHistory() async {
    final saved = _local.readChat(_userId);
    return saved.isEmpty ? [_greeting()] : saved;
  }

  @override
  Future<void> saveHistory(List<VitaMessage> messages) =>
      _local.writeChat(_userId, messages);

  @override
  Future<VitaMessage> reply(
    List<VitaMessage> history, {
    MealPlan? draftPlan,
  }) async {
    final snapshot = await _snapshots.build();
    final stress = _computeStress(snapshot);
    final message = await _remote.chat(
      history: history,
      snapshot: {
        ..._payload(snapshot, stress),
        if (draftPlan != null) ...{
          'activeDietPlan': HealthSnapshotBuilder.planLines(draftPlan),
          'activeDietPlanNote': 'Draft the user is reviewing; not saved yet.',
        },
      },
    );
    if (message.text.isEmpty) {
      throw const VitaException("Vita couldn't respond right now. Please try again.");
    }
    return message;
  }

  // --- Insights -------------------------------------------------------------

  @override
  Future<HealthAnalysis> getHealthAnalysis() async {
    final snapshot = await _snapshots.build();
    final stress = _computeStress(snapshot);
    final cached = _local.readInsights(_userId);
    return HealthAnalysis(
      signals: _analysis.build(snapshot, stress),
      headline: _isToday(cached?.date) ? cached?.headline : null,
    );
  }

  @override
  Future<StressReport> getStressReport() async {
    final snapshot = await _snapshots.build();
    final report = _computeStress(snapshot);
    await _local.writeScore(_userId, snapshot.takenAt, report.score);
    final canConnect =
        await _vitals.isAvailable() && !snapshot.vitals.connected;
    final cached = _local.readInsights(_userId);
    return report.copyWith(
      tip: _isToday(cached?.date) ? cached?.stressTip : null,
      canConnectWearable: canConnect,
    );
  }

  @override
  Future<void> saveStressCheckIn(
    int level, {
    List<StressTag> tags = const [],
  }) async {
    await _local.addCheckIn(
      _userId,
      StressCheckIn(date: DateTime.now(), level: level.clamp(1, 5), tags: tags),
    );
    _events?.logged(const HabitLogged(Habit.mood));
  }

  @override
  List<StressCheckIn> getStressCheckIns() =>
      _local.readCheckIns(_userId)..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<bool> connectWearable() => _vitals.connect();

  @override
  Future<VitaDailyInsights?> getDailyInsights() {
    final cached = _local.readInsights(_userId);
    if (cached != null && _isToday(cached.date)) return Future.value(cached);
    return _insightsInFlight ??= _fetchInsights(cached).whenComplete(() {
      _insightsInFlight = null;
    });
  }

  Future<VitaDailyInsights?> _fetchInsights(VitaDailyInsights? stale) async {
    try {
      final snapshot = await _snapshots.build();
      final data = await _remote.insights(
        _payload(snapshot, _computeStress(snapshot)),
      );
      final insights = VitaDailyInsights.fromJson({
        ...data,
        'date': DateTime.now().toIso8601String(),
      });
      await _local.writeInsights(_userId, insights);
      return insights;
    } catch (e) {
      debugPrint('Vita insights unavailable: $e');
      return stale;
    }
  }

  // --- Helpers ----------------------------------------------------------------

  StressReport _computeStress(HealthSnapshot snapshot) {
    final now = snapshot.takenAt;
    final checkIns = _local.readCheckIns(_userId);
    final today = checkIns.where((c) => _sameDay(c.date, now)).lastOrNull;
    final yesterday = _local.readScores(_userId)[VitaLocalDataSource.dayKey(
      now.subtract(const Duration(days: 1)),
    )];
    return _stress.estimate(
      snapshot: snapshot,
      checkIn: today,
      yesterdayScore: yesterday,
    );
  }

  Map<String, dynamic> _payload(HealthSnapshot snapshot, StressReport stress) => {
        ...snapshot.toJson(),
        'stress': {
          'score0to100': stress.score,
          'level': stress.level.name,
          'basedOn': stress.source.name,
          if (stress.todayCheckIn != null) 'checkIn': stress.todayCheckIn!.label,
          'triggers': [
            for (final t in stress.triggers) '${t.name} (${t.severity.label})',
          ],
        },
      };

  static bool _isToday(DateTime? date) =>
      date != null && _sameDay(date, DateTime.now());

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
