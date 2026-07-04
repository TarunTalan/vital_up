import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingRemoteDataSource remoteDataSource;

  OnboardingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> submitOnboardingData(OnboardingData data) async {
    try {
      await remoteDataSource.submitOnboardingData(data);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(_mapExceptionMessage(e.message)));
    } catch (e) {
      return Left(ServerFailure(_mapExceptionMessage(e.toString())));
    }
  }

  String _mapExceptionMessage(String originalMessage) {
    final msg = originalMessage.toLowerCase();
    if (msg.contains('socketexception') || 
        msg.contains('network') || 
        msg.contains('connection') || 
        msg.contains('handshake') || 
        msg.contains('failed host lookup') ||
        msg.contains('clientexception')) {
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
