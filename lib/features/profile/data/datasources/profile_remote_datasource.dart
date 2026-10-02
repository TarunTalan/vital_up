import 'dart:io';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileEntity> getProfile();

  /// Saves [profile]. The table writes are queued when offline (and sent by
  /// SyncService later); [previous] — the copy on screen / in cache — lets
  /// unchanged parts be skipped. Returns true when everything reached the
  /// server now, false when some of it is queued.
  Future<bool> updateProfile(ProfileEntity profile, {ProfileEntity? previous});

  Future<String> uploadProfilePhoto(String userId, File imageFile);
  Future<void> removeProfilePhoto(String userId);
}
