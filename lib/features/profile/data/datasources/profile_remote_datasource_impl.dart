import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient supabaseClient;
  final Logger logger;

  ProfileRemoteDataSourceImpl({
    required this.supabaseClient,
    required this.logger,
  });

  @override
  Future<ProfileEntity> getProfile() async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        throw const ServerException(message: 'User is not authenticated');
      }
      final userId = user.id;

      // 1. Fetch profiles table details
      final profileRes = await supabaseClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final username = profileRes['username'] as String? ?? '';
      final email = profileRes['email'] as String? ?? user.email ?? '';

      // 2. Fetch user_health_data table details
      final healthRes = await supabaseClient
          .from('user_health_data')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final String fullName = healthRes?['full_name'] as String? ??
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          '';

      final String photoUrl = user.userMetadata?['avatar_url'] ??
          user.userMetadata?['picture'] ??
          '';

      return ProfileEntity(
        id: userId,
        username: username,
        email: email,
        fullName: fullName,
        dob: healthRes?['dob'] as String? ?? '',
        gender: healthRes?['gender'] as String? ?? '',
        weight: healthRes?['weight'] as String? ?? '',
        weightUnit: healthRes?['weight_unit'] as String? ?? 'kg',
        height: healthRes?['height'] as String? ?? '',
        heightUnit: healthRes?['height_unit'] as String? ?? 'cm',
        oxygenLevel: healthRes?['oxygen_level'] as String? ?? '',
        healthConditions: healthRes?['health_conditions'] as String? ?? '',
        allergies: healthRes?['allergies'] as String? ?? '',
        medicines: healthRes?['medicines'] as String? ?? '',
        smokes: healthRes?['smokes'] as String? ?? '',
        bloodPressureTop: healthRes?['blood_pressure_top'] as String? ?? '',
        bloodPressureBottom: healthRes?['blood_pressure_bottom'] as String? ?? '',
        bpm: healthRes?['bpm'] as String? ?? '',
        activity: healthRes?['activity'] as String? ?? '',
        sleep: healthRes?['sleep'] as String? ?? '',
        photoUrl: photoUrl.isEmpty ? null : photoUrl,
      );
    } catch (e) {
      logger.e('Error fetching profile from Supabase: $e');
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updateProfile(ProfileEntity profile) async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        throw const ServerException(message: 'User is not authenticated');
      }

      // 1. Update profiles table
      await supabaseClient.from('profiles').update({
        'username': profile.username,
      }).eq('id', user.id);

      // 2. Update user_health_data table
      final payload = {
        'id': user.id,
        'full_name': profile.fullName,
        'dob': profile.dob,
        'gender': profile.gender,
        'weight': profile.weight,
        'weight_unit': profile.weightUnit,
        'height': profile.height,
        'height_unit': profile.heightUnit,
        'oxygen_level': profile.oxygenLevel,
        'health_conditions': profile.healthConditions,
        'medicines': profile.medicines,
        'allergies': profile.allergies,
        'smokes': profile.smokes,
        'blood_pressure_top': profile.bloodPressureTop,
        'blood_pressure_bottom': profile.bloodPressureBottom,
        'bpm': profile.bpm,
        'activity': profile.activity,
        'sleep': profile.sleep,
        'onboarding_completed': true,
      };

      await supabaseClient.from('user_health_data').upsert(payload);

      // 3. Update auth metadata (such as full_name and avatar_url)
      final metaUpdates = <String, dynamic>{
        'full_name': profile.fullName,
      };
      if (profile.photoUrl != null) {
        metaUpdates['avatar_url'] = profile.photoUrl;
      }

      await supabaseClient.auth.updateUser(
        UserAttributes(
          data: metaUpdates,
        ),
      );

      logger.i('Successfully updated profile for user: ${user.id}');
    } catch (e) {
      logger.e('Error updating profile in Supabase: $e');
      throw ServerException(message: e.toString());
    }
  }
}
