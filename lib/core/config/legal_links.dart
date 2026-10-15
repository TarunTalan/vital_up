import 'package:url_launcher/url_launcher.dart';

/// Hosted legal pages, opened from About, the sign-up terms and (natively)
/// Health Connect's "why this app needs access" link.
///
/// Production URLs on vitalup.live. Keep in sync with
/// `android/app/src/main/res/values/strings.xml` (`privacy_policy_url`).
abstract final class LegalLinks {
  static const privacyPolicy = 'https://vitalup.live/privacy';
  static const terms = 'https://vitalup.live/terms';

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
