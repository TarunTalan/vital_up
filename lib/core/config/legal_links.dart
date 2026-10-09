import 'package:url_launcher/url_launcher.dart';

/// Hosted legal pages, opened from About, the sign-up terms and (natively)
/// Health Connect's "why this app needs access" link.
///
/// PLACEHOLDERS: replace both URLs before release. The privacy policy URL
/// is also in `android/app/src/main/res/values/strings.xml`
/// (`privacy_policy_url`); keep them the same.
abstract final class LegalLinks {
  static const privacyPolicy = 'https://vitalup.example/privacy';
  static const terms = 'https://vitalup.example/terms';

  /// Opens [url] in the browser. False when no app could open it.
  static Future<bool> open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
