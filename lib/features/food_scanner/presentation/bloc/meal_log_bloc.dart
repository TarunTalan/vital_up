import 'package:flutter_bloc/flutter_bloc.dart';
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
    result.fold(
      (failure) => emit(MealLogError(failure.message)),
      (_) async => await _fetchAndEmit(emit),
    );
  }

  Future<void> _fetchAndEmit(Emitter<MealLogState> emit) async {
    final result = await getMealLogHistory(DateTime.now());
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
