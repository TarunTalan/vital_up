import 'package:equatable/equatable.dart';
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

  Future<void> load([TrendRange? range]) async {
    final r = range ?? state.range;
    emit(TrendState<L>(range: r, data: state.data));
    try {
      final data = await _loader(r).withLoadTimeout();
      if (isClosed) return;
      emit(TrendState<L>(range: r, loading: false, data: data));
    } catch (e) {
      if (isClosed) return;
      emit(TrendState<L>(
        range: r,
        loading: false,
        data: state.data,
        error: e.toString(),
      ));
    }
  }
}
