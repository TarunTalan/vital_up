import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile();
  Future<Either<Failure, void>> updateProfile(ProfileEntity profile);
}
