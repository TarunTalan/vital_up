abstract class AuthLocalDataSource {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> saveRegistrationToken(String token);
  Future<String?> getRegistrationToken();
  Future<void> clearRegistrationToken();
  Future<void> saveTokens(String accessToken, String refreshToken, [String? username]);
  Future<void> saveGoogleAuthToken(String accessToken, String refreshToken);
  Future<String?> getUsername();
  Future<bool> isLoggedIn();
  Future<String?> getAuthType();
  Future<void> clearTokens();
  Future<void> saveUser(String userJson);
  Future<String?> getUser();
  Future<void> clearUser();
  Future<void> setOnboardingCompleted(bool completed);
  Future<bool> hasCompletedOnboarding();
}
