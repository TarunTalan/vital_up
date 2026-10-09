import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:isar_community/isar.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/delete_meal_log.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';

class MealLogBloc extends Bloc<MealLogEvent, MealLogState> {
  final GetMealLogHistory getMealLogHistory;
  final DeleteMealLog deleteMealLog;
  final IsarService isarService;

  MealLogBloc({
    required this.getMealLogHistory,
    required this.deleteMealLog,
    required this.isarService,
  }) : super(const MealLogLoading()) {
    on<LoadTodaysMeals>(_onLoad);
    on<RefreshAfterSave>(_onRefresh);
    on<DeleteMealLogEntry>(_onDelete);
  }

  Future<void> _onLoad(LoadTodaysMeals event, Emitter<MealLogState> emit) async {
    emit(const MealLogLoading());
    await _fetchAndEmit(emit);
  }

  Future<void> _onRefresh(RefreshAfterSave event, Emitter<MealLogState> emit) async {
    await _fetchAndEmit(emit);
  }

  Future<void> _onDelete(DeleteMealLogEntry event, Emitter<MealLogState> emit) async {
    final result = await deleteMealLog(event.id);
    // The fold's async branch was never awaited, so the reload emitted after
    // the handler had finished. Await it here instead.
    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      // Keep showing the list; only report the failed delete.
      final current = state;
      if (current is MealLogLoaded) {
        emit(MealLogLoaded(
          entries: current.entries,
          totalCalories: current.totalCalories,
          totalProteinG: current.totalProteinG,
          totalCarbsG: current.totalCarbsG,
          totalFatG: current.totalFatG,
          dailyCalorieGoal: current.dailyCalorieGoal,
          notice: "Couldn't delete this meal. Try again.",
        ));
      } else {
        emit(MealLogError(failure.message));
      }
      return;
    }
    await _fetchAndEmit(emit);
  }

  Future<void> _fetchAndEmit(Emitter<MealLogState> emit) async {
    final Either<Failure, List<MealLogEntry>> result;
    try {
      result = await getMealLogHistory(DateTime.now()).withLoadTimeout();
    } catch (e) {
      addError(e);
      emit(const MealLogError(kLoadErrorMessage));
      return;
    }
    // Read calorie goal from Isar UserProfileCache first
    int? calorieGoal;
    try {
      final profiles = await isarService.isar.userProfileCaches.where().findAll();
      if (profiles.isNotEmpty) {
        calorieGoal = profiles.first.dailyCalorieGoal;
      }
    } catch (_) {
      // Non-critical — dashboard still shows raw totals
    }

    result.fold(
      (failure) => emit(MealLogError(failure.message)),
      (entries) {
        // Aggregate daily totals
        double calories = 0, protein = 0, carbs = 0, fat = 0;
        for (final entry in entries) {
          calories += entry.totalCalories;
          for (final nut in entry.nutrition) {
            protein += nut.proteinG;
            carbs += nut.carbsG;
            fat += nut.fatG;
          }
        }

        emit(MealLogLoaded(
          entries: entries,
          totalCalories: calories,
          totalProteinG: protein,
          totalCarbsG: carbs,
          totalFatG: fat,
          dailyCalorieGoal: calorieGoal,
        ));
      },
    );
  }
}
