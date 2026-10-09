import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/profile/data/profile_cache.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';

class OnboardingRemoteDataSourceImpl implements OnboardingRemoteDataSource {
  final SupabaseClient supabaseClient;
  final PendingWrites pendingWrites;
  final Logger logger;

  OnboardingRemoteDataSourceImpl({
    required this.supabaseClient,
    required this.pendingWrites,
    required this.logger,
  });

  /// The `user_health_data` row written for [data].
  static Map<String, dynamic> payloadFor(String userId, OnboardingData data) => {
        'id': userId,
        'full_name': ProfileRules.cleanName(data.fullName),
        'dob': data.dob,
        'gender': data.gender,
        'weight': data.weight,
        'weight_unit': data.weightUnit,
        'height': data.height,
        'height_unit': data.heightUnit,
        'calorie_goal': int.tryParse(data.calorieGoal),
        'target_weight': double.tryParse(data.targetWeight),
        'target_weight_unit': data.targetWeightUnit,
        'goal_duration_months': int.tryParse(data.goalDurationMonths),
        'health_conditions': ProfileRules.cleanNote(data.healthConditions),
        'medicines': ProfileRules.cleanNote(data.medicines),
        'allergies': ProfileRules.cleanNote(data.allergies),
        'smokes': data.smokes,
        'blood_pressure_top': data.bloodPressureTop,
        'blood_pressure_bottom': data.bloodPressureBottom,
        'dietary_preference': data.dietaryPreference,
        'activity': data.activity,
        'sleep': data.sleep,
        'onboarding_completed': true,
      };

  @override
  Future<bool> submitOnboardingData(OnboardingData data) async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        throw const ServerException(message: 'User is not authenticated');
      }

      // Same outbox key as profile edits, so offline changes to the row
      // coalesce into one upsert.
      final sent = await pendingWrites.sendOrQueue(
        supabaseClient,
        PendingWrite.upsert(
          'user_health_data',
          values: payloadFor(user.id, data),
          userId: user.id,
          key: ProfileCache.healthWriteKey(user.id),
        ),
      );

      logger.i(sent
          ? 'Successfully submitted onboarding data for user: ${user.id}'
          : 'Onboarding data queued offline for user: ${user.id}');
      return sent;
    } on ServerException {
      rethrow;
    } catch (e) {
      logger.e('Error submitting onboarding data: $e');
      throw ServerException(message: e.toString());
    }
  }
}
