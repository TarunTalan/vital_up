import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SupabaseClient supabaseClient;
  final Logger logger;

  SubscriptionRepositoryImpl({
    required this.supabaseClient,
    required this.logger,
  });

  @override
  Future<Either<Failure, bool>> isPremium() async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        return const Left(ServerFailure('User not authenticated'));
      }

      final response = await supabaseClient.rpc('is_premium_user', params: {'p_user_id': userId});
      
      final isPremium = response as bool? ?? false;
      return Right(isPremium);
    } catch (e) {
      logger.e('Error checking premium status: $e');
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

      final response = await supabaseClient.rpc('get_remaining_scans', params: {'p_user_id': userId});
      
      final remaining = response as int? ?? 0;
      return Right(remaining);
    } catch (e) {
      logger.e('Error checking remaining scans: $e');
      return const Left(ServerFailure('Failed to check scan quota'));
    }
  }

  @override
  Future<Either<Failure, Unit>> refreshSubscriptionStatus() async {
    try {
      // This would typically call the RevenueCat SDK to refresh
      // For now, we'll just query the database to ensure we have the latest status
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        return const Left(ServerFailure('User not authenticated'));
      }

      await supabaseClient
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .single();

      return const Right(unit);
    } catch (e) {
      logger.e('Error refreshing subscription status: $e');
      return const Left(ServerFailure('Failed to refresh subscription status'));
    }
  }
}
