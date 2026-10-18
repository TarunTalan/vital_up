import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_timer.dart';

/// The one workout being timed, kept in prefs so it survives the app being
/// closed. There is never more than one.
class WorkoutTimerStore {
  /// Removed on sign out (`AccountService.clearLocalUserData`).
  static const String key = 'workout_timer_v1';

  /// Port the app listens on for writes made by a background isolate (the
  /// notification's Pause / Resume buttons).
  static const String _portName = 'vitalup_workout_timer_changes';

  /// Fires after every write or clear in this isolate, and after one made
  /// by a background isolate (prefs are reloaded first, so [read] sees it).
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  static ReceivePort? _port;

  final SharedPreferences prefs;

  WorkoutTimerStore(this.prefs);

  Stream<void> get changes {
    _listenToOtherIsolates();
    return _changes.stream;
  }

  WorkoutTimer? read() => WorkoutTimer.decode(prefs.getString(key));

  Future<void> write(WorkoutTimer timer) async {
    await prefs.setString(key, timer.encode());
    _changes.add(null);
  }

  Future<void> clear() async {
    await prefs.remove(key);
    _changes.add(null);
  }

  /// Called by a background isolate after it wrote the timer.
  static void notifyOtherIsolates() {
    IsolateNameServer.lookupPortByName(_portName)?.send(null);
  }

  /// Only the app isolate listens (it is the one reading [changes]).
  void _listenToOtherIsolates() {
    if (_port != null) return;
    final port = ReceivePort();
    // A mapping left by an earlier isolate (hot restart) would win.
    IsolateNameServer.removePortNameMapping(_portName);
    if (!IsolateNameServer.registerPortWithName(port.sendPort, _portName)) {
      port.close();
      return;
    }
    _port = port;
    port.listen((_) async {
      try {
        await prefs.reload();
      } catch (e) {
        debugPrint('Reloading workout timer failed: $e');
      }
      _changes.add(null);
    });
  }
}
