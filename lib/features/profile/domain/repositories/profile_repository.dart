import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  /// Served from the local cache while it's fresh (and whenever offline);
  /// [forceRefresh] always asks the server first.
  Future<Either<Failure, ProfileEntity>> getProfile({
    bool forceRefresh = false,
  });

  /// The signed-in user's profile every time any writer changes it (an
  /// edit on any screen, a photo change, onboarding, a server refresh).
  Stream<ProfileEntity> get changes;

  /// Saves locally at once; server writes are queued while offline.
  Future<Either<Failure, void>> updateProfile(ProfileEntity profile);

  /// Uploads [imageFile] as the user's profile photo; returns its public URL.
  Future<Either<Failure, String>> uploadProfilePhoto(
    String userId,
    File imageFile,
  );

  Future<Either<Failure, void>> removeProfilePhoto(String userId);
}
