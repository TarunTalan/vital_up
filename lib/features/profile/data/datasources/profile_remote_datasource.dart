import 'dart:io';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileEntity> getProfile();
  Future<void> updateProfile(ProfileEntity profile);
  Future<String> uploadProfilePhoto(String userId, File imageFile);
  Future<void> removeProfilePhoto(String userId);
}
