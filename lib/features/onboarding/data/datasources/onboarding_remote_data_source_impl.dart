import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';

class OnboardingRemoteDataSourceImpl implements OnboardingRemoteDataSource {
  final SupabaseClient supabaseClient;
  final Logger logger;

  OnboardingRemoteDataSourceImpl({
    required this.supabaseClient,
    required this.logger,
  });

  @override
  Future<void> submitOnboardingData(OnboardingData data) async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        throw const ServerException(message: 'User is not authenticated');
      }

      final payload = {
        'id': user.id,
        'full_name': data.fullName,
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
        'health_conditions': data.healthConditions,
        'medicines': data.medicines,
        'allergies': data.allergies,
        'smokes': data.smokes,
        'blood_pressure_top': data.bloodPressureTop,
        'blood_pressure_bottom': data.bloodPressureBottom,
        'bpm': data.bpm,
        'activity': data.activity,
        'sleep': data.sleep,
        'onboarding_completed': true,
      };

      await supabaseClient
          .from('user_health_data')
          .upsert(payload);

      logger.i('Successfully submitted onboarding data for user: ${user.id}');
    } catch (e) {
      logger.e('Error submitting onboarding data: $e');
      throw ServerException(message: e.toString());
    }
  }
}
