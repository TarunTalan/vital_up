import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/gamification/data/services/daily_metrics_collector.dart';
import 'package:vital_up/features/gamification/domain/entities/daily_metrics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityCalendarState extends Equatable {
  final DateTime selectedDate;
  final DateTime focusedMonth;
  final bool loading;

  /// The selected day couldn't be loaded (shows a retry, not another day).
  final bool failed;
  final DailyMetrics? selectedMetrics;
  final Map<DateTime, DailyMetrics> monthMetrics;

  const ActivityCalendarState({
    required this.selectedDate,
    required this.focusedMonth,
    this.loading = false,
    this.failed = false,
    this.selectedMetrics,
    this.monthMetrics = const {},
  });

  ActivityCalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedMonth,
    bool? loading,
    bool? failed,
    DailyMetrics? selectedMetrics,
    bool clearSelected = false,
    Map<DateTime, DailyMetrics>? monthMetrics,
  }) {
    return ActivityCalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
      selectedMetrics: clearSelected
          ? null
          : selectedMetrics ?? this.selectedMetrics,
      monthMetrics: monthMetrics ?? this.monthMetrics,
    );
  }

  @override
  List<Object?> get props => [
    selectedDate,
    focusedMonth,
    loading,
    failed,
    selectedMetrics,
    monthMetrics,
  ];
}

class ActivityCalendarCubit extends Cubit<ActivityCalendarState> {
  final DailyMetricsCollector _collector;
  final SupabaseClient _client;

  ActivityCalendarCubit(this._collector, this._client, DateTime initialDate)
    : super(
        ActivityCalendarState(
          selectedDate: startOfDay(initialDate),
          focusedMonth: DateTime(initialDate.year, initialDate.month, 1),
          loading: true,
        ),
      ) {
    loadMonth(state.focusedMonth);
    selectDate(state.selectedDate);
  }

  Future<void> selectDate(DateTime date) async {
    final d = startOfDay(date);
    // Drop the previous day's figures at once, so they can never show
    // under the new date (e.g. when this load fails).
    emit(
      state.copyWith(
        selectedDate: d,
        loading: true,
        failed: false,
        clearSelected: true,
      ),
    );

    // Check if we already have it in monthMetrics
    if (state.monthMetrics.containsKey(d)) {
      emit(
        state.copyWith(selectedMetrics: state.monthMetrics[d], loading: false),
      );
      return;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      emit(state.copyWith(loading: false));
      return;
    }

    try {
      final metrics = await _collector.collect(userId, d).withLoadTimeout();
      // Another day was picked meanwhile: that load owns the state.
      if (isClosed || state.selectedDate != d) return;
      emit(state.copyWith(selectedMetrics: metrics, loading: false));
    } catch (e) {
      debugPrint('Calendar day failed to load: $e');
      if (isClosed || state.selectedDate != d) return;
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  Future<void> loadMonth(DateTime month) async {
    final m = DateTime(month.year, month.month, 1);
    emit(state.copyWith(focusedMonth: m));

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final today = startOfDay(now);

      // Determine range to load (from 1st of month to either end of month or today, whichever is earlier)
      // Future dates have no metrics
      final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
      final daysToLoad = <DateTime>[];

      for (int i = 1; i <= daysInMonth; i++) {
        final d = DateTime(m.year, m.month, i);
        if (d.isAfter(today)) break;
        daysToLoad.add(d);
      }

      // One read per store for the whole month, not one per day.
      final results = await _collector
          .collectDays(userId, daysToLoad, now: now)
          .withLoadTimeout();

      // Moved to another month meanwhile.
      if (isClosed || state.focusedMonth != m) return;

      final Map<DateTime, DailyMetrics> newMap = Map.of(state.monthMetrics);
      for (final r in results) {
        newMap[startOfDay(r.day)] = r;
      }

      emit(
        state.copyWith(
          monthMetrics: newMap,
          // selectedMetrics always belongs to selectedDate (cleared when the
          // date changes), so keeping it is safe.
          selectedMetrics: newMap[state.selectedDate] ?? state.selectedMetrics,
          failed: newMap.containsKey(state.selectedDate) ? false : null,
        ),
      );
    } catch (e) {
      debugPrint('Calendar month failed to load: $e');
    }
  }
}
