import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthService {
  static const String _keyBiometricEnabled = 'vitalup_biometric_lock_enabled';

  final LocalAuthentication _auth;
  final SharedPreferences _prefs;

  BiometricAuthService({
    LocalAuthentication? auth,
    required SharedPreferences prefs,
  })  : _auth = auth ?? LocalAuthentication(),
        _prefs = prefs;

  /// Whether the user has enabled biometric app lock in settings
  bool isBiometricEnabled() {
    return _prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Toggle biometric app lock in settings
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      // Test authentication once before enabling
      final success = await authenticate(
        reason: 'Confirm your biometric identity to enable App Lock',
      );
      if (!success) return false;
    }
    await _prefs.setBool(_keyBiometricEnabled, enabled);
    return true;
  }

  /// Check if hardware supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  /// The device has a screen lock (biometrics or PIN/pattern) that can
  /// confirm the user. When it doesn't (lock removed after app lock was
  /// turned on), the app lock can't work and must not trap the user.
  Future<bool> canConfirmUser() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return true; // Unknown: keep the lock, the prompt decides.
    }
  }

  /// Get list of available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// Trigger biometric authentication prompt
  Future<bool> authenticate({
    String reason = 'Authenticate to unlock your VitalUp health records',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // Allows device PIN/pattern fallback
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
