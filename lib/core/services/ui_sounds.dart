import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Short UI sounds played by the app itself (Android `UiSounds`): heard
/// whenever the ringer is on, whatever the "Touch sounds" setting, without
/// pausing music; silent and vibrate mode keep them quiet. Elsewhere (iOS,
/// tests) the system click stands in.
abstract final class UiSounds {
  static const _channel = MethodChannel('com.vitalup.app/feedback');

  static bool get _native =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Loads the sounds ahead of the first [tick].
  static Future<void> prepare() async {
    if (!_native) return;
    try {
      await _channel.invokeMethod<void>('prepare');
    } catch (e) {
      debugPrint('UI sounds not ready: $e');
    }
  }

  /// A dial tick; [strong] for whole units (deeper, a little louder).
  static Future<void> tick({bool strong = false}) async {
    if (_native) {
      try {
        await _channel.invokeMethod<void>('tick', {'strong': strong});
        return;
      } catch (e) {
        debugPrint('UI sound failed: $e');
      }
    }
    await SystemSound.play(SystemSoundType.click);
  }
}
