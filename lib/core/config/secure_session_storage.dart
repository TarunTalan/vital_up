import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Supabase session (access and refresh tokens) in the Android
/// Keystore-backed secure storage instead of plain SharedPreferences.
///
/// The app and the home widget's background engine must both use it, or
/// the widget engine would see no session.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({required String supabaseUrl})
    : _key = 'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

  /// Same key supabase_flutter uses in SharedPreferences, so a session
  /// saved by an older build can be moved over without signing out.
  final String _key;

  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_key);
      if (legacy == null) return;
      if (await _storage.read(key: _key) == null) {
        await _storage.write(key: _key, value: legacy);
      }
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('Moving the saved session failed: $e');
    }
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: _key);
    } catch (e) {
      // A Keystore that can't decrypt (e.g. after a restore) means signed out.
      debugPrint('Reading the saved session failed: $e');
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
}
