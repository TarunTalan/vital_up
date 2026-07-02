import 'package:vital_up/features/auth/data/models/auth_models.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponse> login(LoginRequest request);
  Future<UsernameCheckResponse> checkUsername(String username);
  Future<RegistrationResponse> register(RegistrationRequest request);
  Future<OTPValidationResponse> validateRegistration(ValidateRegistrationRequest request);
  Future<ResendOTPResponse> resendOTP(ResendOTPRequest request);
  Future<OAuthResponse> googleAuth(OAuthRequest request);
  Future<ForgotPasswordResponse> forgotPassword(ForgotPasswordRequest request);
  Future<VerifyForgotPasswordResponse> verifyForgotPassword(VerifyForgotPasswordRequest request);
  Future<ResendForgotPwdResponse> resendForgotOtp(ResendForgotPwdRequest request);
  Future<ResetPwdResponse> resetPassword(ResetPwdRequest request);
  Future<RefreshTokenResponse> refreshToken(RefreshTokenRequest request);
}
