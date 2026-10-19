import 'package:shared_preferences/shared_preferences.dart';

/// The user's choice about sending health data to the AI providers (Vita
/// chat and insights, diet plans). Stored per account on this device; a new
/// device or account asks again.
class VitaAiConsent {
  final SharedPreferences _prefs;
  final String? Function() _userId;

  VitaAiConsent(this._prefs, {required this._userId});

  static String acceptedKey(String userId) => 'vita_ai_consent_v1_$userId';
  static String healthConnectKey(String userId) =>
      'vita_ai_health_connect_v1_$userId';

  /// True once the signed-in user accepted the AI data notice.
  bool get accepted {
    final id = _userId();
    return id != null && (_prefs.getBool(acceptedKey(id)) ?? false);
  }

  /// Health Connect readings go to the AI only with this opt-in (off by
  /// default, and never without [accepted]).
  bool get includeHealthConnect {
    final id = _userId();
    return id != null &&
        accepted &&
        (_prefs.getBool(healthConnectKey(id)) ?? false);
  }

  Future<void> accept({required bool includeHealthConnect}) async {
    final id = _userId();
    if (id == null) return;
    await _prefs.setBool(acceptedKey(id), true);
    await _prefs.setBool(healthConnectKey(id), includeHealthConnect);
  }

  Future<void> setIncludeHealthConnect(bool include) async {
    final id = _userId();
    if (id == null || !accepted) return;
    await _prefs.setBool(healthConnectKey(id), include);
  }

  /// Stops all AI requests until the user accepts the notice again.
  Future<void> withdraw() async {
    final id = _userId();
    if (id == null) return;
    await _prefs.remove(acceptedKey(id));
    await _prefs.remove(healthConnectKey(id));
  }
}
