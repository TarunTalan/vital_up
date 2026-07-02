import 'package:supabase_flutter/supabase_flutter.dart' hide OAuthResponse;
import 'package:logger/logger.dart';
import 'package:vital_up/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:vital_up/features/auth/data/models/auth_models.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _supabaseClient;
  final Logger _logger;

  AuthRemoteDataSourceImpl({
    required this._supabaseClient,
    required this._logger,
  });

  @override
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      String email = request.username;
      
      // If the input doesn't look like an email, assume it's a username
      if (!email.contains('@')) {
         final response = await _supabaseClient.rpc('get_email_by_username', params: {'p_username': request.username});
         if (response != null && response is String && response.isNotEmpty) {
           email = response;
         } else {
           throw const AuthException('Invalid username or password');
         }
      }

      final authResponse = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: request.password,
      );

      return LoginResponse(
        data: LoginData(
            accessToken: authResponse.session?.accessToken ?? '', 
            refreshToken: authResponse.session?.refreshToken ?? ''),
        message: 'Success',
        status: 200,
      );
    } catch (e) {
      _logger.e('Login remote error: $e');
      rethrow;
    }
  }

  @override
  Future<UsernameCheckResponse> checkUsername(String username) async {
    try {
      final response = await _supabaseClient
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      
      final isAvailable = response == null;
      return UsernameCheckResponse(
        available: isAvailable,
        message: isAvailable ? 'Username is available' : 'Username is already taken',
      );
    } catch (e) {
      _logger.e('Check username remote error: $e');
      rethrow;
    }
  }

  @override
  Future<RegistrationResponse> register(RegistrationRequest request) async {
    try {
      await _supabaseClient.auth.signUp(
        email: request.email,
        password: request.password,
        data: {'username': request.username},
      );
      
      return RegistrationResponse(
        data: request.email, // Return email as "token" for OTP steps
        message: 'OTP Sent to ${request.email}',
        status: 200,
      );
    } catch (e) {
      _logger.e('Registration remote error: $e');
      rethrow;
    }
  }

  @override
  Future<OTPValidationResponse> validateRegistration(ValidateRegistrationRequest request) async {
    try {
      await _supabaseClient.auth.verifyOTP(
        type: OtpType.signup,
        token: request.otp,
        email: request.email,
      );

      return OTPValidationResponse(
        data: null,
        message: 'Registration validated successfully',
        status: 200,
      );
    } catch (e) {
      _logger.e('Validate registration remote error: $e');
      rethrow;
    }
  }

  @override
  Future<ResendOTPResponse> resendOTP(ResendOTPRequest request) async {
    try {
      await _supabaseClient.auth.resend(
        type: OtpType.signup,
        email: request.email,
      );
      
      return ResendOTPResponse(
        data: null,
        message: 'OTP Resent successfully',
        status: 200,
      );
    } catch (e) {
      _logger.e('Resend OTP remote error: $e');
      rethrow;
    }
  }

  @override
  Future<OAuthResponse> googleAuth(OAuthRequest request) async {
    try {
      // In Supabase, Google Auth is usually done via signInWithIdToken
      final authResponse = await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: request.idToken,
      );

      return OAuthResponse(
        data: OAuthData(
          accessToken: authResponse.session?.accessToken ?? '',
          refreshToken: authResponse.session?.refreshToken ?? '',
        ),
        message: 'Success',
        status: 200,
      );
    } catch (e) {
      _logger.e('Google auth remote error: $e');
      rethrow;
    }
  }

  @override
  Future<ForgotPasswordResponse> forgotPassword(ForgotPasswordRequest request) async {
    try {
      await _supabaseClient.auth.resetPasswordForEmail(request.email);
      
      return ForgotPasswordResponse(
        data: request.email, // Use email as token
        message: 'OTP Sent successfully',
        status: 200,
      );
    } catch (e) {
      _logger.e('Forgot password remote error: $e');
      rethrow;
    }
  }

  @override
  Future<VerifyForgotPasswordResponse> verifyForgotPassword(VerifyForgotPasswordRequest request) async {
    try {
      await _supabaseClient.auth.verifyOTP(
        type: OtpType.recovery,
        token: request.otp,
        email: request.email,
      );
      
      return VerifyForgotPasswordResponse(
        data: DataVerifyForgotPwd(token: request.email), // After verify OTP, session is created in Supabase
        message: 'OTP verified',
        status: 200,
      );
    } catch (e) {
      _logger.e('Verify forgot password remote error: $e');
      rethrow;
    }
  }

  @override
  Future<ResendForgotPwdResponse> resendForgotOtp(ResendForgotPwdRequest request) async {
    try {
      // Supabase uses the same resetPasswordForEmail to resend
      await _supabaseClient.auth.resetPasswordForEmail(request.email);
      
      return ResendForgotPwdResponse(
        data: request.email,
        message: 'OTP resent',
        status: 200,
      );
    } catch (e) {
      _logger.e('Resend forgot password remote error: $e');
      rethrow;
    }
  }

  @override
  Future<ResetPwdResponse> resetPassword(ResetPwdRequest request) async {
    try {
      // In Supabase, verifyOTP(recovery) automatically logs the user in.
      // So we can just update the user attributes
      await _supabaseClient.auth.updateUser(UserAttributes(
        password: request.newPassword,
      ));
      
      return ResetPwdResponse(
        data: 'Success',
        message: 'Password reset completed successfully',
        status: 200,
      );
    } catch (e) {
      _logger.e('Reset password remote error: $e');
      rethrow;
    }
  }

  @override
  Future<RefreshTokenResponse> refreshToken(RefreshTokenRequest request) async {
    try {
      // Supabase handles refresh automatically, but we can force a refresh if needed
      final response = await _supabaseClient.auth.refreshSession();
      
      return RefreshTokenResponse(
        data: DataRefreshToken(
            accessToken: response.session?.accessToken ?? '', 
            refreshToken: response.session?.refreshToken ?? ''),
        message: 'Success',
        status: 200,
      );
    } catch (e) {
      _logger.e('Refresh token remote error: $e');
      rethrow;
    }
  }
}
