import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vital_up/features/auth/data/datasources/auth_local_data_source.dart';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage _secureStorage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _registrationKey = 'registration_token';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _authTypeKey = 'auth_type';
  static const String _usernameKey = 'username';
  static const String _userKey = 'user_data';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  static const String authTypeEmail = 'email';
  static const String authTypeGoogle = 'google';

  AuthLocalDataSourceImpl({required this._secureStorage});

  @override
  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> saveRegistrationToken(String token) async {
    await _secureStorage.write(key: _registrationKey, value: token);
  }

  @override
  Future<String?> getRegistrationToken() async {
    return await _secureStorage.read(key: _registrationKey);
  }

  @override
  Future<void> clearRegistrationToken() async {
    await _secureStorage.delete(key: _registrationKey);
  }

  @override
  Future<void> saveTokens(String accessToken, String refreshToken, [String? username]) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.write(key: _isLoggedInKey, value: 'true');
    await _secureStorage.write(key: _authTypeKey, value: authTypeEmail);
    if (username != null) {
      await _secureStorage.write(key: _usernameKey, value: username);
    }
  }

  @override
  Future<void> saveGoogleAuthToken(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.write(key: _isLoggedInKey, value: 'true');
    await _secureStorage.write(key: _authTypeKey, value: authTypeGoogle);

    final extractedUsername = _extractUsernameFromToken(accessToken);
    if (extractedUsername != null) {
      await _secureStorage.write(key: _usernameKey, value: extractedUsername);
    }
  }

  @override
  Future<String?> getUsername() async {
    return await _secureStorage.read(key: _usernameKey);
  }

  @override
  Future<bool> isLoggedIn() async {
    final value = await _secureStorage.read(key: _isLoggedInKey);
    return value == 'true';
  }

  @override
  Future<String?> getAuthType() async {
    return await _secureStorage.read(key: _authTypeKey);
  }

  @override
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _registrationKey);
    await _secureStorage.delete(key: _isLoggedInKey);
    await _secureStorage.delete(key: _authTypeKey);
    await _secureStorage.delete(key: _usernameKey);
  }

  @override
  Future<void> saveUser(String userJson) async {
    await _secureStorage.write(key: _userKey, value: userJson);
  }

  @override
  Future<String?> getUser() async {
    return await _secureStorage.read(key: _userKey);
  }

  @override
  Future<void> clearUser() async {
    await _secureStorage.delete(key: _userKey);
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    await _secureStorage.write(key: _onboardingCompletedKey, value: completed ? 'true' : 'false');
  }

  @override
  Future<bool> hasCompletedOnboarding() async {
    final value = await _secureStorage.read(key: _onboardingCompletedKey);
    return value == 'true';
  }

  String? _extractUsernameFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final normalizedPayload = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
      final json = jsonDecode(payloadJson);
      return json['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}
