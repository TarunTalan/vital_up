import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_data_store.dart';

class SharedPreferencesOnboardingDataStore implements OnboardingDataStore {
  final SharedPreferences _prefs;

  SharedPreferencesOnboardingDataStore(this._prefs);

  @override
  Future<String> getFullName() async => _prefs.getString('onboarding_full_name') ?? '';

  @override
  Future<String> getDob() async => _prefs.getString('onboarding_dob') ?? '';

  @override
  Future<String> getGender() async => _prefs.getString('onboarding_gender') ?? '';

  @override
  Future<String> getWeight() async => _prefs.getString('onboarding_weight') ?? '70';

  @override
  Future<String> getWeightUnit() async => _prefs.getString('onboarding_weight_unit') ?? 'kg';

  @override
  Future<String> getHeight() async => _prefs.getString('onboarding_height') ?? '';

  @override
  Future<String> getHeightUnit() async => _prefs.getString('onboarding_height_unit') ?? 'cm';

  @override
  Future<String> getCurrentStep() async => _prefs.getString('onboarding_current_step') ?? 'personal_details';

  @override
  Future<String> getOxygenLevel() async => _prefs.getString('onboarding_oxygen_level') ?? '';

  @override
  Future<String> getHealthConditions() async => _prefs.getString('onboarding_health_conditions') ?? '';

  @override
  Future<String> getMedicines() async => _prefs.getString('onboarding_medicines') ?? '';

  @override
  Future<String> getAllergies() async => _prefs.getString('onboarding_allergies') ?? '';

  @override
  Future<String> getSmokes() async => _prefs.getString('onboarding_smokes') ?? '';

  @override
  Future<String> getBloodPressureTop() async => _prefs.getString('onboarding_bp_top') ?? '';

  @override
  Future<String> getBloodPressureBottom() async => _prefs.getString('onboarding_bp_bottom') ?? '';

  @override
  Future<String> getBpm() async => _prefs.getString('onboarding_bpm') ?? '';

  @override
  Future<String> getActivity() async => _prefs.getString('onboarding_activity') ?? '';

  @override
  Future<String> getSleep() async => _prefs.getString('onboarding_sleep') ?? '';

  @override
  Future<void> savePersonalDetails(String name, String dob, String gender) async {
    await _prefs.setString('onboarding_full_name', name);
    await _prefs.setString('onboarding_dob', dob);
    await _prefs.setString('onboarding_gender', gender);
  }

  @override
  Future<void> saveWeight(String weight, String unit) async {
    await _prefs.setString('onboarding_weight', weight);
    await _prefs.setString('onboarding_weight_unit', unit);
  }

  @override
  Future<void> saveHeight(String height, String unit) async {
    await _prefs.setString('onboarding_height', height);
    await _prefs.setString('onboarding_height_unit', unit);
  }

  @override
  Future<void> saveOxygenLevel(String level) async {
    await _prefs.setString('onboarding_oxygen_level', level);
  }

  @override
  Future<void> saveExtraDetails(String conditions, String medicines, String allergies, String smokes) async {
    await _prefs.setString('onboarding_health_conditions', conditions);
    await _prefs.setString('onboarding_medicines', medicines);
    await _prefs.setString('onboarding_allergies', allergies);
    await _prefs.setString('onboarding_smokes', smokes);
  }

  @override
  Future<void> saveHealthVitals(String bpTop, String bpBottom, String bpm, String activity, String sleep) async {
    await _prefs.setString('onboarding_bp_top', bpTop);
    await _prefs.setString('onboarding_bp_bottom', bpBottom);
    await _prefs.setString('onboarding_bpm', bpm);
    await _prefs.setString('onboarding_activity', activity);
    await _prefs.setString('onboarding_sleep', sleep);
  }

  @override
  Future<void> setCurrentStep(String step) async {
    await _prefs.setString('onboarding_current_step', step);
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool('onboarding_completed', completed);
  }

  @override
  Future<void> clearOnboardingData() async {
    final keys = _prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('onboarding_')) {
        await _prefs.remove(key);
      }
    }
  }
}
