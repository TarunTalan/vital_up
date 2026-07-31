import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileEntity> getProfile();
  Future<void> updateProfile(ProfileEntity profile);
}
