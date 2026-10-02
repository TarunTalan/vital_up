import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/features/food_scanner/data/utils/food_cache_keys.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/subscription_repository.dart';

/// Subscription state is cached per user so it is known offline (a stale
/// answer beats none). Remaining scans change with every photo scan, so that
/// copy is short-lived; a successful scan also decrements it in place (see
/// `FoodRecognitionRepositoryImpl`).
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SupabaseClient supabaseClient;
  final Logger logger;
  final CacheStore cacheStore;

  SubscriptionRepositoryImpl({
    required this.supabaseClient,
    required this.logger,
    required this.cacheStore,
  });

  static const Duration _premiumMaxAge = Duration(hours: 1);
  static const Duration _remainingScansMaxAge = Duration(minutes: 2);

  Future<bool> _isPremium(String userId, {bool forceRefresh = false}) => cacheStore.fetch<bool>(
        FoodCacheKeys.premium(userId),
        maxAge: _premiumMaxAge,
        forceRefresh: forceRefresh,
        decode: (json) => json as bool,
        remote: () async {
          final response = await supabaseClient.rpc('is_premium_user', params: {'p_user_id': userId});
          return response as bool? ?? false;
        },
      );

  Future<int> _remainingScans(String userId, {bool forceRefresh = false}) => cacheStore.fetch<int>(
        FoodCacheKeys.remainingScans(userId),
        maxAge: _remainingScansMaxAge,
        forceRefresh: forceRefresh,
        decode: (json) => (json as num).toInt(),
        remote: () async {
          final response = await supabaseClient.rpc('get_remaining_scans', params: {'p_user_id': userId});
          return (response as num?)?.toInt() ?? 0;
        },
      );

  @override
  Future<Either<Failure, bool>> isPremium() async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        return const Left(ServerFailure('User not authenticated'));
      }
      return Right(await _isPremium(userId));
    } catch (e) {
      logger.e('Error checking premium status: $e');
      if (isOfflineError(e)) return const Left(NetworkFailure());
      return const Left(ServerFailure('Failed to check subscription status'));
    }
  }

  @override
  Future<Either<Failure, int>> remainingFreeScans() async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        return const Left(ServerFailure('User not authenticated'));
      }
      return Right(await _remainingScans(userId));
    } catch (e) {
      logger.e('Error checking remaining scans: $e');
      if (isOfflineError(e)) return const Left(NetworkFailure());
      return const Left(ServerFailure('Failed to check scan quota'));
    }
  }

  @override
  Future<Either<Failure, Unit>> refreshSubscriptionStatus() async {
    try {
      // This would typically call the RevenueCat SDK to refresh. For now,
      // re-read both values from the server, bypassing the cache (offline
      // the cached copies are kept).
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        return const Left(ServerFailure('User not authenticated'));
      }

      await Future.wait([
        _isPremium(userId, forceRefresh: true),
        _remainingScans(userId, forceRefresh: true),
      ]);

      return const Right(unit);
    } catch (e) {
      logger.e('Error refreshing subscription status: $e');
      if (isOfflineError(e)) return const Left(NetworkFailure());
      return const Left(ServerFailure('Failed to refresh subscription status'));
    }
  }
}
