import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';

/// Activity levels as onboarding stores them (they feed the calorie goal).
const activityLevels = [
  'Mostly resting',
  'Light movement',
  'Moderate activity',
  'Very active',
];

const smokerOptions = ['No', 'Occasionally', 'Yes'];

/// Height in cm from the profile ("170" cm or "5-7" ft-in).
double? profileHeightCm(ProfileEntity p) =>
    CalculateCalorieGoal.heightInCm(p.height, p.heightUnit);

/// Weight in kg from the profile, whatever unit it was saved in.
double? profileWeightKg(ProfileEntity p) =>
    CalculateCalorieGoal.weightInKg(p.weight, p.weightUnit);

int? profileAge(ProfileEntity p) => CalculateCalorieGoal.ageFromDob(p.dob);

/// Settings' height unit: 'in' shows feet and inches.
bool usesImperialHeight(SettingsEntity s) => s.heightUnit == 'in';

/// "178 cm" or "5 ft 10 in".
String formatHeight(double cm, SettingsEntity settings) {
  if (!usesImperialHeight(settings)) return '${cm.round()} cm';
  final totalInches = (cm / CalculateCalorieGoal.cmPerInch).round();
  return '${totalInches ~/ 12} ft ${totalInches % 12} in';
}

/// "Male" from "male".
String displayGender(String gender) => gender.isEmpty
    ? ''
    : gender[0].toUpperCase() + gender.substring(1).toLowerCase();

double? bmiOf({double? kg, double? cm}) {
  if (kg == null || cm == null || cm <= 0) return null;
  final m = cm / 100;
  return kg / (m * m);
}

/// WHO adult BMI bands.
enum BmiBand {
  under('Underweight'),
  healthy('Healthy range'),
  over('Overweight'),
  obese('Obese');

  final String label;
  const BmiBand(this.label);

  static BmiBand of(double bmi) => bmi < 18.5
      ? under
      : bmi < 25
      ? healthy
      : bmi < 30
      ? over
      : obese;

  Color color(BuildContext context) => switch (this) {
    healthy => context.vColors.success!,
    under || over => context.vColors.warning!,
    obese => context.colors.error,
  };
}

/// Comma-separated medical history field as a list.
List<String> splitList(String value) => value
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty && e.toLowerCase() != 'none')
    .toList();

/// Current settings (units), or the defaults until they load.
SettingsEntity watchSettings(BuildContext context) {
  final state = context.watch<SettingsCubit>().state;
  return state is SettingsLoaded ? state.settings : const SettingsEntity();
}
