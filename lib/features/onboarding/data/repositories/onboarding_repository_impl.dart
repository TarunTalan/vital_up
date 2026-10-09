import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_remote_data_source_impl.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:vital_up/features/profile/data/profile_cache.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingRemoteDataSource remoteDataSource;
  final AuthLocalDataSource authLocalDataSource;
  final CacheStore cacheStore;

  /// The signed-in user's id, or null.
  final String? Function() currentUserId;

  OnboardingRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
    required this.cacheStore,
    required this.currentUserId,
  });

  /// Succeeds offline too: the answers are queued and uploaded on reconnect,
  /// so finishing onboarding without a connection doesn't block the user.
  @override
  Future<Either<Failure, void>> submitOnboardingData(OnboardingData data) async {
    try {
      await remoteDataSource.submitOnboardingData(data);
      final userId = currentUserId();
      if (userId != null) await _saveLocally(userId, data);
      return const Right(null);
    } catch (e) {
      debugPrint('Onboarding submit failed: $e');
      return Left(ServerFailure(_messageFor(e)));
    }
  }

  /// Local state that would otherwise wait for the server: the completion
  /// flag the auth check falls back to offline, and the cached profile /
  /// goal weight the dashboard and weight chart read.
  Future<void> _saveLocally(String userId, OnboardingData data) async {
    try {
      await authLocalDataSource.setOnboardingCompleted(userId, true);
      await cacheStore.update(
        ProfileCache.key(userId),
        (cached) => ProfileCache.patch(
          cached,
          OnboardingRemoteDataSourceImpl.payloadFor(userId, data),
        ),
      );
      final target = double.tryParse(data.targetWeight);
      if (target != null && target > 0) {
        await cacheStore.write(
          WeightService.targetCacheKey(userId),
          WeightUnit.fromCode(data.targetWeightUnit).toKg(target),
        );
      }
    } catch (e) {
      debugPrint('Onboarding local state not saved: $e');
    }
  }

  /// Short message for the user; details go to the log.
  static String _messageFor(Object error) {
    const fallback = "Couldn't save your details. Try again.";
    final text = error is ServerException ? error.message : '$error';
    if (isOfflineError(error) || isOfflineError(text)) {
      return "You're offline. Try again when connected.";
    }
    if (text.contains('not authenticated')) return 'Please sign in again.';
    return userMessage(error, fallback: fallback);
  }
}
