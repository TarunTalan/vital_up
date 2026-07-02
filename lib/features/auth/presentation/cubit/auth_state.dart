import 'package:equatable/equatable.dart';
import 'package:vital_up/features/auth/domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

// OTP verification for Sign up registration
class AuthOtpSent extends AuthState {
  final String token;
  final String email;

  const AuthOtpSent({required this.token, required this.email});

  @override
  List<Object?> get props => [token, email];
}

// OTP verification for Forgot password
class AuthForgotPasswordOtpSent extends AuthState {
  final String token;
  final String email;

  const AuthForgotPasswordOtpSent({required this.token, required this.email});

  @override
  List<Object?> get props => [token, email];
}

// Forgot password OTP successfully verified, ready for reset
class AuthForgotPasswordOtpVerified extends AuthState {
  final String token; // Reset password token
  final String email;

  const AuthForgotPasswordOtpVerified({required this.token, required this.email});

  @override
  List<Object?> get props => [token, email];
}

// Password reset complete
class AuthPasswordResetSuccess extends AuthState {}

class AuthOtpVerified extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
