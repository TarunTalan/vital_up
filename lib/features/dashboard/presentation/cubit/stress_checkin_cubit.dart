import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';

class StressCheckInState extends Equatable {
  final StressCheckIn? today;

  /// Last 7 days, oldest first; null where nothing was logged.
  final List<StressCheckIn?> week;
  final int streak;

  /// Picker selection while choosing (or editing) today's mood.
  final int? selectedLevel;
  final Set<StressTag> selectedTags;
  final bool editing;

  /// Bumped on every successful log so the card can play its celebration.
  final int celebrations;

  const StressCheckInState({
    this.today,
    this.week = const [],
    this.streak = 0,
    this.selectedLevel,
    this.selectedTags = const {},
    this.editing = false,
    this.celebrations = 0,
  });

  /// Showing the face picker (not logged yet today, or editing).
  bool get picking => today == null || editing;

  StressCheckInState copyWith({
    StressCheckIn? Function()? today,
    List<StressCheckIn?>? week,
    int? streak,
    int? Function()? selectedLevel,
    Set<StressTag>? selectedTags,
    bool? editing,
    int? celebrations,
  }) =>
      StressCheckInState(
        today: today == null ? this.today : today(),
        week: week ?? this.week,
        streak: streak ?? this.streak,
        selectedLevel:
            selectedLevel == null ? this.selectedLevel : selectedLevel(),
        selectedTags: selectedTags ?? this.selectedTags,
        editing: editing ?? this.editing,
        celebrations: celebrations ?? this.celebrations,
      );

  @override
  List<Object?> get props => [
        today,
        week,
        streak,
        selectedLevel,
        selectedTags,
        editing,
        celebrations,
      ];
}

/// Dashboard mood check-in: pick a face, optional tags, log; tracks the
/// daily streak and the last 7 days.
class StressCheckInCubit extends Cubit<StressCheckInState> {
  final VitaRepository _repository;

  StressCheckInCubit(this._repository) : super(const StressCheckInState());

  @override
  void emit(StressCheckInState state) {
    if (!isClosed) super.emit(state);
  }

  void load() {
    final List<StressCheckIn> checkIns;
    try {
      checkIns = _repository.getStressCheckIns();
    } catch (e) {
      debugPrint('Mood check-ins unavailable: $e');
      return;
    }
    final byDay = {for (final c in checkIns) startOfDay(c.date): c};
    final days = lastNDays(7);
    emit(state.copyWith(
      today: () => byDay[days.last],
      week: [for (final d in days) byDay[d]],
      streak: stressStreak(checkIns),
    ));
  }

  Future<void> reload() async {
    try {
      await _repository.reload();
    } catch (e) {
      debugPrint('Mood check-ins not reloaded: $e');
    }
    load();
  }

  void selectLevel(int level) =>
      emit(state.copyWith(selectedLevel: () => level));

  void toggleTag(StressTag tag) {
    final tags = Set.of(state.selectedTags);
    if (!tags.remove(tag)) tags.add(tag);
    emit(state.copyWith(selectedTags: tags));
  }

  void edit() {
    final today = state.today;
    emit(state.copyWith(
      editing: true,
      selectedLevel: () => today?.level,
      selectedTags: {...?today?.tags},
    ));
  }

  void cancelEdit() => emit(state.copyWith(
        editing: false,
        selectedLevel: () => null,
        selectedTags: const {},
      ));

  /// Saves the picked mood. Returns false when it couldn't be saved.
  Future<bool> submit() async {
    final level = state.selectedLevel;
    if (level == null) return false;
    try {
      await _repository.saveStressCheckIn(
        level,
        tags: StressTag.values.where(state.selectedTags.contains).toList(),
      );
    } catch (e) {
      debugPrint('Mood check-in not saved: $e');
      return false;
    }
    if (isClosed) return true;
    emit(state.copyWith(
      editing: false,
      selectedLevel: () => null,
      selectedTags: const {},
      celebrations: state.celebrations + 1,
    ));
    load();
    return true;
  }
}
