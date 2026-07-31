abstract class OnboardingDataStore {
  Future<String> getFullName();
  Future<String> getDob();
  Future<String> getGender();
  Future<String> getWeight();
  Future<String> getWeightUnit();
  Future<String> getHeight();
  Future<String> getHeightUnit();
  Future<String> getCurrentStep();
  Future<String> getCalorieGoal();
  Future<String> getTargetWeight();
  Future<String> getTargetWeightUnit();
  Future<String> getGoalDurationMonths();
  Future<String> getHealthConditions();
  Future<String> getMedicines();
  Future<String> getAllergies();
  Future<String> getSmokes();
  Future<String> getBloodPressureTop();
  Future<String> getBloodPressureBottom();
  Future<String> getBpm();
  Future<String> getActivity();
  Future<String> getSleep();

  Future<void> savePersonalDetails(String name, String dob, String gender);
  Future<void> saveWeight(String weight, String unit);
  Future<void> saveHeight(String height, String unit);
  Future<void> saveGoals(String calorieGoal, String targetWeight, String targetWeightUnit, String goalDurationMonths);
  Future<void> saveExtraDetails(String conditions, String medicines, String allergies, String smokes);
  Future<void> saveHealthVitals(String bpTop, String bpBottom, String bpm, String activity, String sleep);
  
  Future<void> setCurrentStep(String step);
  Future<void> setOnboardingCompleted(bool completed);
  Future<void> clearOnboardingData();
}
