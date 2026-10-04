import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/gamification/data/services/daily_metrics_collector.dart';
import 'package:vital_up/features/gamification/domain/entities/daily_metrics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityCalendarState extends Equatable {
  final DateTime selectedDate;
  final DateTime focusedMonth;
  final bool loading;
  final DailyMetrics? selectedMetrics;
  final Map<DateTime, DailyMetrics> monthMetrics;

  const ActivityCalendarState({
    required this.selectedDate,
    required this.focusedMonth,
    this.loading = false,
    this.selectedMetrics,
    this.monthMetrics = const {},
  });

  ActivityCalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedMonth,
    bool? loading,
    DailyMetrics? selectedMetrics,
    Map<DateTime, DailyMetrics>? monthMetrics,
  }) {
    return ActivityCalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      loading: loading ?? this.loading,
      selectedMetrics: selectedMetrics ?? this.selectedMetrics,
      monthMetrics: monthMetrics ?? this.monthMetrics,
    );
  }

  @override
  List<Object?> get props => [
        selectedDate,
        focusedMonth,
        loading,
        selectedMetrics,
        monthMetrics,
      ];
}

class ActivityCalendarCubit extends Cubit<ActivityCalendarState> {
  final DailyMetricsCollector _collector;
  final SupabaseClient _client;

  ActivityCalendarCubit(
    this._collector,
    this._client,
    DateTime initialDate,
  ) : super(ActivityCalendarState(
          selectedDate: startOfDay(initialDate),
          focusedMonth: DateTime(initialDate.year, initialDate.month, 1),
          loading: true,
        )) {
    loadMonth(state.focusedMonth);
    selectDate(state.selectedDate);
  }

  Future<void> selectDate(DateTime date) async {
    final d = startOfDay(date);
    emit(state.copyWith(selectedDate: d, loading: true));
    
    // Check if we already have it in monthMetrics
    if (state.monthMetrics.containsKey(d)) {
      emit(state.copyWith(
        selectedMetrics: state.monthMetrics[d],
        loading: false,
      ));
      return;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      emit(state.copyWith(loading: false));
      return;
    }

    try {
      final metrics = await _collector.collect(userId, d);
      if (isClosed) return;
      emit(state.copyWith(
        selectedMetrics: metrics,
        loading: false,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(loading: false));
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

      final results = await Future.wait(
        daysToLoad.map((d) => _collector.collect(userId, d, now: now)),
      );

      if (isClosed) return;

      final Map<DateTime, DailyMetrics> newMap = Map.of(state.monthMetrics);
      for (final r in results) {
        newMap[startOfDay(r.day)] = r;
      }

      emit(state.copyWith(
        monthMetrics: newMap,
        selectedMetrics: newMap[state.selectedDate] ?? state.selectedMetrics,
      ));
    } catch (_) {}
  }
}
