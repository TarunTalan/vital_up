import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/gamification/domain/entities/award_result.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';

class GamificationState extends Equatable {
  final PlayerStats? stats;

  /// Points earned today per category.
  final Map<ScoreCategory, int> today;

  /// Last load failed or timed out with nothing cached (any earlier
  /// [stats] is kept). Offline, loads return the last cached values.
  final bool failed;

  /// Latest level-up / new-badge result to celebrate; [awardId] changes
  /// with every new one so listeners fire once per award.
  final AwardResult? award;
  final int awardId;

  const GamificationState({
    this.stats,
    this.today = const {},
    this.failed = false,
    this.award,
    this.awardId = 0,
  });

  int get todayTotal => today.values.fold(0, (sum, p) => sum + p);

  GamificationState copyWith({
    PlayerStats? stats,
    Map<ScoreCategory, int>? today,
    bool? failed,
    AwardResult? award,
    int? awardId,
  }) => GamificationState(
    stats: stats ?? this.stats,
    today: today ?? this.today,
    failed: failed ?? this.failed,
    award: award ?? this.award,
    awardId: awardId ?? this.awardId,
  );

  @override
  List<Object?> get props => [stats, today, failed, award, awardId];
}

class GamificationCubit extends Cubit<GamificationState> {
  final GamificationRepository _repository;

  /// Coalesces bursts of changes (logging water three times) into one sync.
  static const syncDebounce = Duration(seconds: 2);

  Timer? _debounce;
  bool _syncing = false;
  bool _syncAgain = false;
  StreamSubscription<bool>? _online;

  /// [onlineChanges] (ConnectivityService) sends days reported offline as
  /// soon as the network is back.
  GamificationCubit(this._repository, {Stream<bool>? onlineChanges})
    : super(const GamificationState()) {
    _online = onlineChanges?.where((online) => online).listen((_) => sync());
  }

  Future<void> load() async {
    try {
      final (stats, today) = await (
        _repository.getStats(),
        _repository.getPointsForDay(DateTime.now()),
      ).wait.withLoadTimeout();
      if (isClosed) return;
      emit(state.copyWith(stats: stats, today: today, failed: false));
    } catch (e) {
      debugPrint('Gamification stats failed to load: $e');
      if (isClosed) return;
      emit(state.copyWith(failed: true));
    }
  }

  /// Reports today's (and any unsynced earlier days') metrics soon.
  void sync() {
    _debounce?.cancel();
    _debounce = Timer(syncDebounce, _runSync);
  }

  /// Reports right away, e.g. on first open.
  Future<void> syncNow() {
    _debounce?.cancel();
    return _runSync();
  }

  Future<void> _runSync() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      final award = await _repository.sync().withLoadTimeout();
      if (isClosed) return;
      if (award != null && award.celebrate) {
        emit(state.copyWith(award: award, awardId: state.awardId + 1));
      }
    } catch (e) {
      // Offline or server error: the next sync re-sends these days.
      debugPrint('Gamification sync failed: $e');
    } finally {
      _syncing = false;
    }
    await load();
    if (_syncAgain && !isClosed) {
      _syncAgain = false;
      sync();
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _online?.cancel();
    return super.close();
  }
}
