import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/onboarding_data.dart';
import '../../data/datasources/onboarding_data_store.dart';
import '../../domain/repositories/onboarding_repository.dart';
class OnboardingCubit extends Cubit<OnboardingData> {
  final OnboardingDataStore _onboardingDataStore;
  final OnboardingRepository _onboardingRepository;

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
    final oxygenLevel = await _onboardingDataStore.getOxygenLevel();
    final healthConditions = await _onboardingDataStore.getHealthConditions();
    final medicines = await _onboardingDataStore.getMedicines();
    final allergies = await _onboardingDataStore.getAllergies();
    final smokes = await _onboardingDataStore.getSmokes();
    final bpTop = await _onboardingDataStore.getBloodPressureTop();
    final bpBottom = await _onboardingDataStore.getBloodPressureBottom();
    final bpm = await _onboardingDataStore.getBpm();
    final activity = await _onboardingDataStore.getActivity();
    final sleep = await _onboardingDataStore.getSleep();

    emit(OnboardingData(
      fullName: fullName,
      dob: dob,
      gender: gender,
      weight: weight.isEmpty ? "70" : weight,
      weightUnit: weightUnit.isEmpty ? "kg" : weightUnit,
      height: height,
      heightUnit: heightUnit.isEmpty ? "cm" : heightUnit,
      oxygenLevel: oxygenLevel,
      healthConditions: healthConditions,
      medicines: medicines,
      allergies: allergies,
      smokes: smokes,
      bloodPressureTop: bpTop,
      bloodPressureBottom: bpBottom,
      bpm: bpm,
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

  Future<void> updateOxygenLevel(String level) async {
    emit(state.copyWith(oxygenLevel: level));
    await _onboardingDataStore.saveOxygenLevel(level);
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
    String? bpm,
    String? activity,
    String? sleep,
  }) async {
    final newTop = bpTop ?? state.bloodPressureTop;
    final newBottom = bpBottom ?? state.bloodPressureBottom;
    final newBpm = bpm ?? state.bpm;
    final newActivity = activity ?? state.activity;
    final newSleep = sleep ?? state.sleep;
    
    emit(state.copyWith(
      bloodPressureTop: newTop,
      bloodPressureBottom: newBottom,
      bpm: newBpm,
      activity: newActivity,
      sleep: newSleep,
    ));
    await _onboardingDataStore.saveHealthVitals(newTop, newBottom, newBpm, newActivity, newSleep);
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
    emit(state.copyWith(status: SubmissionStatus.submitting, errorMessage: null));

    final result = await _onboardingRepository.submitOnboardingData(state);

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: SubmissionStatus.error,
          errorMessage: failure.message,
        ));
      },
      (_) async {
        await completeOnboarding(); // Mark locally as completed
        emit(state.copyWith(status: SubmissionStatus.success));
      },
    );
  }
}
