import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/onboarding_data.dart';
import '../../data/datasources/onboarding_data_store.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../../domain/usecases/calculate_calorie_goal.dart';
class OnboardingCubit extends Cubit<OnboardingData> {
  final OnboardingDataStore _onboardingDataStore;
  final OnboardingRepository _onboardingRepository;
  final CalculateCalorieGoal _calculateCalorieGoal = const CalculateCalorieGoal();

  OnboardingCubit(this._onboardingDataStore, this._onboardingRepository) : super(const OnboardingData()) {
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final fullName = await _onboardingDataStore.getFullName();
    final dob = await _onboardingDataStore.getDob();
    final gender = await _onboardingDataStore.getGender();
    final weight = await _onboardingDataStore.getWeight();
    final weightUnit = await _onboardingDataStore.getWeightUnit();
    final height = await _onboardingDataStore.getHeight();
    final heightUnit = await _onboardingDataStore.getHeightUnit();
    final savedStep = await _onboardingDataStore.getCurrentStep();
    final calorieGoal = await _onboardingDataStore.getCalorieGoal();
    final targetWeight = await _onboardingDataStore.getTargetWeight();
    final targetWeightUnit = await _onboardingDataStore.getTargetWeightUnit();
    final goalDurationMonths = await _onboardingDataStore.getGoalDurationMonths();
    final goalType = await _onboardingDataStore.getGoalType();
    final weeklyPace = await _onboardingDataStore.getWeeklyPace();
    final healthConditions = await _onboardingDataStore.getHealthConditions();
    final medicines = await _onboardingDataStore.getMedicines();
    final allergies = await _onboardingDataStore.getAllergies();
    final smokes = await _onboardingDataStore.getSmokes();
    final bpTop = await _onboardingDataStore.getBloodPressureTop();
    final bpBottom = await _onboardingDataStore.getBloodPressureBottom();
    final dietaryPreference = await _onboardingDataStore.getDietaryPreference();
    final activity = await _onboardingDataStore.getActivity();
    final sleep = await _onboardingDataStore.getSleep();
    if (isClosed) return;

    emit(OnboardingData(
      fullName: fullName,
      dob: dob,
      gender: gender,
      weight: weight.isEmpty ? "70" : weight,
      weightUnit: weightUnit.isEmpty ? "kg" : weightUnit,
      height: height,
      heightUnit: heightUnit.isEmpty ? "cm" : heightUnit,
      calorieGoal: calorieGoal,
      targetWeight: targetWeight,
      targetWeightUnit: targetWeightUnit,
      goalDurationMonths: goalDurationMonths,
      goalType: goalType,
      weeklyPace: weeklyPace,
      healthConditions: healthConditions,
      medicines: medicines,
      allergies: allergies,
      smokes: smokes,
      bloodPressureTop: bpTop,
      bloodPressureBottom: bpBottom,
      dietaryPreference: dietaryPreference,
      activity: activity,
      sleep: sleep,
      currentStep: savedStep.isEmpty ? "personal_details" : savedStep,
    ));
  }

  Future<void> updateFullName(String name) async {
    emit(state.copyWith(fullName: name));
    await _onboardingDataStore.savePersonalDetails(name, state.dob, state.gender);
  }

  Future<void> updateDob(String dob) async {
    emit(state.copyWith(dob: dob));
    await _onboardingDataStore.savePersonalDetails(state.fullName, dob, state.gender);
  }

  Future<void> updateGender(String gender) async {
    emit(state.copyWith(gender: gender));
    await _onboardingDataStore.savePersonalDetails(state.fullName, state.dob, gender);
  }

  Future<void> updateWeight(String weight, String unit) async {
    emit(state.copyWith(weight: weight, weightUnit: unit));
    await _onboardingDataStore.saveWeight(weight, unit);
  }

  Future<void> updateHeight(String height, String unit) async {
    emit(state.copyWith(height: height, heightUnit: unit));
    await _onboardingDataStore.saveHeight(height, unit);
  }

  /// Saves the goal step. The calorie goal itself is derived later, once
  /// activity level is known (see [submitOnboardingDataToBackend]).
  Future<void> updateGoals({
    required String goalType,
    required String weeklyPace,
    required String targetWeight,
    required String targetWeightUnit,
    required String goalDurationMonths,
  }) async {
    emit(state.copyWith(
      goalType: goalType,
      weeklyPace: weeklyPace,
      targetWeight: targetWeight,
      targetWeightUnit: targetWeightUnit,
      goalDurationMonths: goalDurationMonths,
    ));
    await _onboardingDataStore.saveGoals(
      state.calorieGoal,
      targetWeight,
      targetWeightUnit,
      goalDurationMonths,
      goalType,
      weeklyPace,
    );
  }

  Future<void> updateHealthConditions(String conditions) async {
    emit(state.copyWith(healthConditions: conditions));
    await _onboardingDataStore.saveExtraDetails(
      conditions,
      state.medicines,
      state.allergies,
      state.smokes,
    );
  }

  Future<void> updateMedicines(String medicines) async {
    emit(state.copyWith(medicines: medicines));
    await _onboardingDataStore.saveExtraDetails(
      state.healthConditions,
      medicines,
      state.allergies,
      state.smokes,
    );
  }

  Future<void> updateAllergies(String allergies) async {
    emit(state.copyWith(allergies: allergies));
    await _onboardingDataStore.saveExtraDetails(
      state.healthConditions,
      state.medicines,
      allergies,
      state.smokes,
    );
  }

  Future<void> updateSmoke(String smokes) async {
    emit(state.copyWith(smokes: smokes));
    await _onboardingDataStore.saveExtraDetails(
      state.healthConditions,
      state.medicines,
      state.allergies,
      smokes,
    );
  }

  Future<void> updateHealthVitals({
    String? bpTop,
    String? bpBottom,
    String? dietaryPreference,
    String? activity,
    String? sleep,
  }) async {
    final newTop = bpTop ?? state.bloodPressureTop;
    final newBottom = bpBottom ?? state.bloodPressureBottom;
    final newDietaryPreference = dietaryPreference ?? state.dietaryPreference;
    final newActivity = activity ?? state.activity;
    final newSleep = sleep ?? state.sleep;
    
    emit(state.copyWith(
      bloodPressureTop: newTop,
      bloodPressureBottom: newBottom,
      dietaryPreference: newDietaryPreference,
      activity: newActivity,
      sleep: newSleep,
    ));
    await _onboardingDataStore.saveHealthVitals(newTop, newBottom, newDietaryPreference, newActivity, newSleep);
  }

  Future<void> setCurrentStep(String step) async {
    emit(state.copyWith(currentStep: step));
    await _onboardingDataStore.setCurrentStep(step);
  }

  Future<void> completeOnboarding() async {
    await _onboardingDataStore.setOnboardingCompleted(true);
  }

  Future<void> clearData() async {
    emit(const OnboardingData());
    await _onboardingDataStore.clearOnboardingData();
  }

  Future<void> submitOnboardingDataToBackend() async {
    // Double taps on "Done" would upload twice.
    if (state.status == SubmissionStatus.submitting) return;
    emit(state.copyWith(status: SubmissionStatus.submitting));

    // Personalised calorie goal from TDEE + chosen pace.
    final calorieGoal = _calculateCalorieGoal(state);
    if (calorieGoal != null) {
      emit(state.copyWith(calorieGoal: calorieGoal.toString()));
      await _onboardingDataStore.saveCalorieGoal(calorieGoal.toString());
    }

    final result = await _onboardingRepository.submitOnboardingData(state);
    if (isClosed) return;

    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(
        status: SubmissionStatus.error,
        errorMessage: failure.message,
      ));
      return;
    }
    try {
      await completeOnboarding(); // Mark locally as completed
    } catch (e) {
      // The server has the answers; the flag is only a local shortcut.
      debugPrint('Onboarding completion flag not saved: $e');
    }
    if (!isClosed) emit(state.copyWith(status: SubmissionStatus.success));
  }
}
