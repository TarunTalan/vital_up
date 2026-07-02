class LoginRequest {
  final String username;
  final String password;

  LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };
}

class LoginResponse {
  final LoginData? data;
  final String message;
  final int status;

  LoginResponse({this.data, required this.message, required this.status});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      data: json['data'] != null ? LoginData.fromJson(json['data']) : null,
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class LoginData {
  final String accessToken;
  final String refreshToken;

  LoginData({required this.accessToken, required this.refreshToken});

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }
}

class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() => {
        'email': email,
      };
}

class ForgotPasswordResponse {
  final String? data;
  final String message;
  final int status;

  ForgotPasswordResponse({this.data, required this.message, required this.status});

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      data: json['data'] as String?,
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class VerifyForgotPasswordRequest {
  final String email;
  final String otp;
  final String token;

  VerifyForgotPasswordRequest({
    required this.email,
    required this.otp,
    required this.token,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'otp': otp,
        'token': token,
      };
}

class VerifyForgotPasswordResponse {
  final DataVerifyForgotPwd? data;
  final String message;
  final int status;

  VerifyForgotPasswordResponse({this.data, required this.message, required this.status});

  factory VerifyForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return VerifyForgotPasswordResponse(
      data: json['data'] != null ? DataVerifyForgotPwd.fromJson(json['data']) : null,
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class DataVerifyForgotPwd {
  final String token;

  DataVerifyForgotPwd({required this.token});

  factory DataVerifyForgotPwd.fromJson(Map<String, dynamic> json) {
    return DataVerifyForgotPwd(
      token: json['token'] as String? ?? '',
    );
  }
}

class UsernameCheckResponse {
  final bool available;
  final String? message;

  UsernameCheckResponse({required this.available, this.message});

  factory UsernameCheckResponse.fromJson(Map<String, dynamic> json) {
    return UsernameCheckResponse(
      available: json['available'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}

class RegistrationRequest {
  final String email;
  final String username;
  final String password;

  RegistrationRequest({
    required this.email,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'username': username,
        'password': password,
      };
}

class RegistrationResponse {
  final String? data; // JWT token
  final String message;
  final int status;

  RegistrationResponse({this.data, required this.message, required this.status});

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      data: json['data'] as String?,
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class ValidateRegistrationRequest {
  final String email;
  final String otp;
  final String type;
  final String token;

  ValidateRegistrationRequest({
    required this.email,
    required this.otp,
    this.type = 'REGISTRATION',
    required this.token,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'otp': otp,
        'type': type,
        'Token': token, // backend uses @SerializedName("Token")
      };
}

class OTPValidationResponse {
  final dynamic data;
  final String message;
  final int status;

  OTPValidationResponse({this.data, required this.message, required this.status});

  factory OTPValidationResponse.fromJson(Map<String, dynamic> json) {
    return OTPValidationResponse(
      data: json['data'],
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class ResendOTPRequest {
  final String email;
  final String token;

  ResendOTPRequest({required this.email, required this.token});

  Map<String, dynamic> toJson() => {
        'email': email,
        'token': token,
      };
}

class ResendOTPResponse {
  final dynamic data;
  final String message;
  final int status;

  ResendOTPResponse({this.data, required this.message, required this.status});

  factory ResendOTPResponse.fromJson(Map<String, dynamic> json) {
    return ResendOTPResponse(
      data: json['data'],
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class OAuthRequest {
  final String idToken;

  OAuthRequest({required this.idToken});

  Map<String, dynamic> toJson() => {
        'idToken': idToken,
      };
}

class OAuthResponse {
  final OAuthData? data;
  final String message;
  final int status;

  OAuthResponse({this.data, required this.message, required this.status});

  factory OAuthResponse.fromJson(Map<String, dynamic> json) {
    return OAuthResponse(
      data: json['data'] != null ? OAuthData.fromJson(json['data']) : null,
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class OAuthData {
  final String accessToken;
  final String refreshToken;

  OAuthData({required this.accessToken, required this.refreshToken});

  factory OAuthData.fromJson(Map<String, dynamic> json) {
    return OAuthData(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }
}

class ResendForgotPwdRequest {
  final String email;
  final String token;

  ResendForgotPwdRequest({required this.email, required this.token});

  Map<String, dynamic> toJson() => {
        'email': email,
        'token': token,
      };
}

class ResendForgotPwdResponse {
  final String data;
  final String message;
  final int status;

  ResendForgotPwdResponse({required this.data, required this.message, required this.status});

  factory ResendForgotPwdResponse.fromJson(Map<String, dynamic> json) {
    return ResendForgotPwdResponse(
      data: json['data'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class ResetPwdRequest {
  final String newPassword;
  final String token;

  ResetPwdRequest({required this.newPassword, required this.token});

  Map<String, dynamic> toJson() => {
        'newPassword': newPassword,
        'Token': token, // Matches Token parameter in ResetPwdRequest
      };
}

class ResetPwdResponse {
  final String? data;
  final String message;
  final int status;

  ResetPwdResponse({this.data, required this.message, required this.status});

  factory ResetPwdResponse.fromJson(Map<String, dynamic> json) {
    return ResetPwdResponse(
      data: json['data'] as String?,
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class RefreshTokenRequest {
  final String refreshToken;

  RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {
        'refreshToken': refreshToken,
      };
}

class RefreshTokenResponse {
  final DataRefreshToken? data;
  final String message;
  final int status;

  RefreshTokenResponse({this.data, required this.message, required this.status});

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      data: json['data'] != null ? DataRefreshToken.fromJson(json['data']) : null,
      message: json['message'] as String? ?? '',
      status: json['status'] as int? ?? 0,
    );
  }
}

class DataRefreshToken {
  final String accessToken;
  final String refreshToken;

  DataRefreshToken({required this.accessToken, required this.refreshToken});

  factory DataRefreshToken.fromJson(Map<String, dynamic> json) {
    return DataRefreshToken(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }
}
