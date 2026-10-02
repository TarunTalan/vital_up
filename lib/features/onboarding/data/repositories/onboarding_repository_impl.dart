import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/offline_errors.dart';
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
    } on ServerException catch (e) {
      return Left(ServerFailure(_mapExceptionMessage(e.message)));
    } catch (e) {
      return Left(ServerFailure(_mapExceptionMessage(e.toString())));
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

  String _mapExceptionMessage(String originalMessage) {
    final msg = originalMessage.toLowerCase();
    if (isOfflineError(originalMessage)) {
      return 'No internet connection. Please check your network settings.';
    }
    if (msg.contains('postgrestexception') || msg.contains('database') || msg.contains('postgres') || msg.contains('upsert')) {
      return 'Database operation failed. Please try again.';
    }
    // Remove technical prefixes like 'Exception: ' if present
    final cleanMsg = originalMessage.replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (cleanMsg.length < 60 && !cleanMsg.contains('{') && !cleanMsg.contains('[')) {
      return cleanMsg;
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
