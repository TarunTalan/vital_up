import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signIn(String username, String password);
  Future<Either<Failure, String>> signUp(String username, String email, String password); // Returns registration token
  Future<Either<Failure, void>> verifyRegistrationOTP({
    required String email,
    required String otp,
    required String token,
  });
  Future<Either<Failure, void>> resendRegistrationOTP({
    required String email,
    required String token,
  });
  Future<Either<Failure, String>> checkUsernameAvailability(String username);
  Future<Either<Failure, String>> requestForgotPassword(String email); // Returns verification token
  Future<Either<Failure, String>> verifyForgotPassword({
    required String email,
    required String otp,
    required String token,
  }); // Returns reset password token
  Future<Either<Failure, String>> resendForgotPasswordOTP({
    required String email,
    required String token,
  }); // Returns new verification token
  Future<Either<Failure, void>> resetPassword({
    required String newPassword,
    required String token,
  });
  Future<Either<Failure, UserEntity>> signInWithGoogle();
  Future<Either<Failure, void>> signOut();
  Future<Either<Failure, UserEntity?>> getCurrentUser();
  Future<Either<Failure, bool>> isSessionActive();
}
