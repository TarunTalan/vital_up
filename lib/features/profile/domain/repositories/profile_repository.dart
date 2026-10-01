import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile();
  Future<Either<Failure, void>> updateProfile(ProfileEntity profile);

  /// Uploads [imageFile] as the user's profile photo; returns its public URL.
  Future<Either<Failure, String>> uploadProfilePhoto(String userId, File imageFile);

  Future<Either<Failure, void>> removeProfilePhoto(String userId);
}
