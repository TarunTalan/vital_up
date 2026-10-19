import 'package:vital_up/core/config/env.dart';

/// Legacy configuration bridge that delegates to [Env].
/// 
/// Kept for backward compatibility with existing feature imports.
/// All sensitive values are securely obfuscated at compile time via Envied.
class SupabaseConfig {
  static String get url => Env.supabaseUrl;
  static String get publishableKey => Env.supabasePublishableKey;
  static String get mapboxAccessToken => Env.mapboxAccessToken;
  static String get googleWebClientId => Env.googleWebClientId;
}
