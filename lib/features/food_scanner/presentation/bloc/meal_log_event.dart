import 'dart:async';

import 'package:equatable/equatable.dart';

abstract class MealLogEvent extends Equatable {
  const MealLogEvent();

  @override
  List<Object?> get props => [];
}

/// Load today's meal logs on init / tab switch.
class LoadTodaysMeals extends MealLogEvent {
  const LoadTodaysMeals();
}

/// Load all meal logs history across all dates.
class LoadAllMealLogs extends MealLogEvent {
  /// Completed when the load has finished, so pull-to-refresh can keep
  /// its spinner until then.
  final Completer<void>? done;

  const LoadAllMealLogs({this.done});
}

/// Triggered after FoodScanBloc saves a meal — refreshes today's totals.
class RefreshAfterSave extends MealLogEvent {
  const RefreshAfterSave();
}

/// Delete a specific meal log entry by its ID.
class DeleteMealLogEntry extends MealLogEvent {
  final String id;
  const DeleteMealLogEntry(this.id);

  @override
  List<Object?> get props => [id];
}
