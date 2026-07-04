import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:vital_up/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:vital_up/features/auth/data/models/auth_models.dart';
import 'package:vital_up/features/auth/domain/entities/user_entity.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  AuthRepositoryImpl({
    required this._remoteDataSource,
    required this._localDataSource,
  });

  @override
  Future<Either<Failure, UserEntity>> signIn(String username, String password) async {
    try {
      final response = await _remoteDataSource.login(
        LoginRequest(username: username, password: password),
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data!;
        await _localDataSource.saveAccessToken(data.accessToken);
        await _localDataSource.saveRefreshToken(data.refreshToken);

        // Fetch actual user metadata if possible, but mock for now as Supabase handles it
        final user = UserEntity(
          id: Supabase.instance.client.auth.currentUser?.id ?? 'usr_1',
          email: Supabase.instance.client.auth.currentUser?.email ?? '$username@example.com',
          displayName: username,
        );
        await _localDataSource.saveUser(jsonEncode({
          'id': user.id,
          'email': user.email,
          'displayName': user.displayName,
        }));

        return Right(user);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> signUp(String username, String email, String password) async {
    try {
      final response = await _remoteDataSource.register(
        RegistrationRequest(email: email, username: username, password: password),
      );

      if (response.status == 200 && response.data != null) {
        return Right(response.data!);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> verifyRegistrationOTP({
    required String email,
    required String otp,
    required String token,
  }) async {
    try {
      final response = await _remoteDataSource.validateRegistration(
        ValidateRegistrationRequest(email: email, otp: otp, token: token),
      );

      if (response.status == 200) {
        final session = Supabase.instance.client.auth.currentSession;
        final currentUser = Supabase.instance.client.auth.currentUser;
        
        if (session != null && currentUser != null) {
          await _localDataSource.saveAccessToken(session.accessToken);
          await _localDataSource.saveRefreshToken(session.refreshToken ?? '');
          
          final user = UserEntity(
            id: currentUser.id,
            email: currentUser.email ?? email,
            displayName: currentUser.userMetadata?['username'] ?? email.split('@')[0],
          );
          
          await _localDataSource.saveUser(jsonEncode({
            'id': user.id,
            'email': user.email,
            'displayName': user.displayName,
          }));
        }
        return const Right(null);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resendRegistrationOTP({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _remoteDataSource.resendOTP(
        ResendOTPRequest(email: email, token: token),
      );

      if (response.status == 200) {
        return const Right(null);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> checkUsernameAvailability(String username) async {
    try {
      final response = await _remoteDataSource.checkUsername(username);
      if (response.available) {
        return Right(response.message ?? 'Username is available');
      } else {
        return Left(ValidationFailure(response.message ?? 'Username is already taken'));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> requestForgotPassword(String email) async {
    try {
      final response = await _remoteDataSource.forgotPassword(
        ForgotPasswordRequest(email: email),
      );

      if (response.status == 200 && response.data != null) {
        return Right(response.data!);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> verifyForgotPassword({
    required String email,
    required String otp,
    required String token,
  }) async {
    try {
      final response = await _remoteDataSource.verifyForgotPassword(
        VerifyForgotPasswordRequest(email: email, otp: otp, token: token),
      );

      if (response.status == 200 && response.data != null) {
        return Right(response.data!.token);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> resendForgotPasswordOTP({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _remoteDataSource.resendForgotOtp(
        ResendForgotPwdRequest(email: email, token: token),
      );

      if (response.status == 200) {
        return Right(response.data);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String newPassword,
    required String token,
  }) async {
    try {
      final response = await _remoteDataSource.resetPassword(
        ResetPwdRequest(newPassword: newPassword, token: token),
      );

      if (response.status == 200) {
        return const Right(null);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      // 1. Initialize Google Sign-In with standard scopes and Web Client ID
      final googleSignIn = GoogleSignIn(
        clientId: SupabaseConfig.googleWebClientId,
        scopes: ['email', 'profile'],
      );

      // 2. Perform native device sign-in
      // Clear previous cached session first to force the Google Account Chooser dialog
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return Left(ServerFailure('Google sign-in cancelled by user'));
      }

      // 3. Obtain authentication credentials
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        return Left(ServerFailure('Google Authentication failed: Missing ID Token'));
      }

      // 4. Authenticate session via remote data source (Supabase GoTrue)
      final response = await _remoteDataSource.googleAuth(
        OAuthRequest(idToken: idToken),
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data!;
        await _localDataSource.saveAccessToken(data.accessToken);
        await _localDataSource.saveRefreshToken(data.refreshToken);

        // 5. Get the actual authenticated user model from the Supabase client
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) {
          return Left(ServerFailure('Failed to retrieve user profile after sign-in'));
        }

        final user = UserEntity(
          id: currentUser.id,
          email: currentUser.email ?? '',
          displayName: currentUser.userMetadata?['full_name'] ??
              currentUser.userMetadata?['name'] ??
              'Google User',
        );

        await _localDataSource.saveUser(jsonEncode({
          'id': user.id,
          'email': user.email,
          'displayName': user.displayName,
        }));

        return Right(user);
      } else {
        return Left(ServerFailure(response.message));
      }
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      await _localDataSource.clearTokens();
      await _localDataSource.clearUser();
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final userJson = await _localDataSource.getUser();
      if (userJson != null) {
        final map = jsonDecode(userJson);
        return Right(UserEntity(
          id: map['id'],
          email: map['email'],
          displayName: map['displayName'],
          photoUrl: map['photoUrl'],
        ));
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isSessionActive() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      return Right(session != null && !session.isExpired);
    } catch (e) {
      return const Right(false);
    }
  }
}
