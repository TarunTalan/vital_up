import 'package:equatable/equatable.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';

abstract class DietPlanState extends Equatable {
  const DietPlanState();

  @override
  List<Object?> get props => [];
}

class DietPlanInitial extends DietPlanState {}

class DietPlanLoading extends DietPlanState {}

class DietPlanLoaded extends DietPlanState {
  final MealPlan mealPlan;

  const DietPlanLoaded(this.mealPlan);

  @override
  List<Object?> get props => [mealPlan];
}

class DietPlanError extends DietPlanState {
  final String message;

  const DietPlanError(this.message);

  @override
  List<Object?> get props => [message];
}
