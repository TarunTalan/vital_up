import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';

abstract class OnboardingRemoteDataSource {
  /// Saves [data] to `user_health_data`. Queued for SyncService when
  /// offline; returns true if it reached the server now.
  Future<bool> submitOnboardingData(OnboardingData data);
}
