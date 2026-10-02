import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

/// Where the full profile lives in [CacheStore], shared by every feature that
/// reads or edits it (profile, onboarding, weight) so they stay in step.
class ProfileCache {
  ProfileCache._();

  static String key(String userId) => 'profile:$userId';

  /// Opening the dashboard repeatedly within this window doesn't refetch.
  static const maxAge = Duration(minutes: 10);

  /// Outbox keys, so repeated offline edits coalesce into one request.
  static String profilesWriteKey(String userId) => 'profile:$userId';
  static String healthWriteKey(String userId) => 'health:$userId';

  static Map<String, dynamic> encode(ProfileEntity p) => {
        'id': p.id,
        'username': p.username,
        'email': p.email,
        'full_name': p.fullName,
        'dob': p.dob,
        'gender': p.gender,
        'weight': p.weight,
        'weight_unit': p.weightUnit,
        'height': p.height,
        'height_unit': p.heightUnit,
        'oxygen_level': p.oxygenLevel,
        'health_conditions': p.healthConditions,
        'allergies': p.allergies,
        'medicines': p.medicines,
        'smokes': p.smokes,
        'blood_pressure_top': p.bloodPressureTop,
        'blood_pressure_bottom': p.bloodPressureBottom,
        'bpm': p.bpm,
        'activity': p.activity,
        'sleep': p.sleep,
        'photo_url': p.photoUrl,
        'calorie_goal': p.dailyCalorieGoal,
      };

  static ProfileEntity decode(Object? json) {
    final m = Map<String, dynamic>.from(json as Map);
    String s(String k, [String fallback = '']) => m[k] as String? ?? fallback;
    return ProfileEntity(
      id: m['id'] as String,
      username: s('username'),
      email: s('email'),
      fullName: s('full_name'),
      dob: s('dob'),
      gender: s('gender'),
      weight: s('weight'),
      weightUnit: s('weight_unit', 'kg'),
      height: s('height'),
      heightUnit: s('height_unit', 'cm'),
      oxygenLevel: s('oxygen_level'),
      healthConditions: s('health_conditions'),
      allergies: s('allergies'),
      medicines: s('medicines'),
      smokes: s('smokes'),
      bloodPressureTop: s('blood_pressure_top'),
      bloodPressureBottom: s('blood_pressure_bottom'),
      bpm: s('bpm'),
      activity: s('activity'),
      sleep: s('sleep'),
      photoUrl: m['photo_url'] as String?,
      dailyCalorieGoal: (m['calorie_goal'] as num?)?.toInt(),
    );
  }

  /// Applies server-column [values] (as written to `user_health_data`) to a
  /// cached profile entry, for writers that only know some fields.
  static Object? patch(Object? cached, Map<String, dynamic> values) {
    if (cached is! Map) return cached;
    const known = {
      'full_name', 'dob', 'gender', 'weight', 'weight_unit', 'height',
      'height_unit', 'oxygen_level', 'health_conditions', 'allergies',
      'medicines', 'smokes', 'blood_pressure_top', 'blood_pressure_bottom',
      'bpm', 'activity', 'sleep', 'calorie_goal', 'username',
    };
    return {
      ...Map<String, dynamic>.from(cached),
      for (final e in values.entries)
        if (known.contains(e.key) && e.value != null) e.key: e.value,
    };
  }
}
