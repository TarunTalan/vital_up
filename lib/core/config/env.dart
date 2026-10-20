import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL')
  static final String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_PUBLISHABLE_KEY')
  static final String supabasePublishableKey = _Env.supabasePublishableKey;

  @EnviedField(varName: 'MAPBOX_ACCESS_TOKEN')
  static final String mapboxAccessToken = _Env.mapboxAccessToken;

  @EnviedField(varName: 'GOOGLE_WEB_CLIENT_ID')
  static final String googleWebClientId = _Env.googleWebClientId;

  /// RevenueCat public SDK key for Google Play (`goog_...`).
  @EnviedField(varName: 'REVENUECAT_GOOGLE_API_KEY', optional: true)
  static final String? revenueCatGoogleApiKey = _Env.revenueCatGoogleApiKey;
}
