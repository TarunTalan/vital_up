import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';

abstract class OnboardingRepository {
  Future<Either<Failure, void>> submitOnboardingData(OnboardingData data);
}
