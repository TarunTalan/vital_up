import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

class TrendState<L> extends Equatable {
  final TrendRange range;
  final bool loading;
  final TrendData<L>? data;
  final String? error;

  const TrendState({
    this.range = TrendRange.week,
    this.loading = true,
    this.data,
    this.error,
  });

  @override
  List<Object?> get props => [range, loading, data, error];
}

/// Loads one metric's trend for the selected range. Shared by the mini
/// charts on dashboard cards and the trend detail pages.
class TrendCubit<L> extends Cubit<TrendState<L>> {
  final Future<TrendData<L>> Function(TrendRange range) _loader;

  TrendCubit(this._loader, {TrendRange range = TrendRange.week})
      : super(TrendState<L>(range: range));

  /// Bumped per load, so a slow earlier load (say 30D, then 7D tapped
  /// quickly) can't overwrite a newer one.
  int _request = 0;

  @override
  void emit(TrendState<L> state) {
    if (!isClosed) super.emit(state);
  }

  Future<void> load([TrendRange? range]) async {
    final r = range ?? state.range;
    final request = ++_request;
    emit(TrendState<L>(range: r, data: state.data));
    try {
      final data = await _loader(r).withLoadTimeout();
      if (request != _request) return;
      emit(TrendState<L>(range: r, loading: false, data: data));
    } catch (e) {
      debugPrint('Trend load failed: $e');
      if (request != _request) return;
      emit(TrendState<L>(
        range: r,
        loading: false,
        data: state.data,
        error: kLoadErrorMessage,
      ));
    }
  }

  /// Drops [log] from the list right away (a swiped-away tile must leave
  /// the tree at once), runs [delete], then reloads either way. Returns
  /// false when [delete] failed; the reload brings the entry back.
  Future<bool> deleteLog(L log, Future<void> Function() delete) async {
    final data = state.data;
    if (data != null) {
      emit(TrendState<L>(
        range: state.range,
        loading: state.loading,
        data: TrendData<L>(data.series, [
          for (final l in data.logs)
            if (!identical(l, log) && l != log) l,
        ]),
        error: state.error,
      ));
    }
    var ok = true;
    try {
      await delete();
    } catch (e) {
      debugPrint('Delete failed: $e');
      ok = false;
    }
    await load();
    return ok;
  }
}
