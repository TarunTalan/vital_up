import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';

abstract class OnboardingRemoteDataSource {
  Future<void> submitOnboardingData(OnboardingData data);
}
