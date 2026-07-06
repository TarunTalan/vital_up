import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';

abstract class SubscriptionRepository {
  Future<Either<Failure, bool>> isPremium();
  
  Future<Either<Failure, int>> remainingFreeScans();
  
  Future<Either<Failure, Unit>> refreshSubscriptionStatus();
}
