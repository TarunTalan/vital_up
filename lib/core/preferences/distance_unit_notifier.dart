import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user prefers metric (km) or imperial (miles) distance display.
enum DistanceUnit {
  km,
  miles;

  /// Human-readable short label shown in the UI.
  String get label => this == DistanceUnit.km ? 'km' : 'mi';

  /// Pace unit label, e.g. "MIN/KM" or "MIN/MI".
  String get paceLabel => this == DistanceUnit.km ? 'MIN/KM' : 'MIN/MI';

  /// Column header for the distance stat, e.g. "DISTANCE (KM)".
  String get distanceLabel =>
      this == DistanceUnit.km ? 'DISTANCE (KM)' : 'DISTANCE (MI)';
}

const _kDistanceUnitKey = 'activity_distance_unit';

/// A [ValueNotifier] that persists the chosen [DistanceUnit] in SharedPreferences.
/// Call [load] once at startup (or before first use) to restore the saved value.
class DistanceUnitNotifier extends ValueNotifier<DistanceUnit> {
  DistanceUnitNotifier() : super(DistanceUnit.km);

  /// Restores the previously saved unit from persistent storage.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDistanceUnitKey);
    if (raw == DistanceUnit.miles.name) {
      value = DistanceUnit.miles;
    } else {
      value = DistanceUnit.km;
    }
  }

  /// Persists [unit] and notifies listeners.
  Future<void> setUnit(DistanceUnit unit) async {
    value = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDistanceUnitKey, unit.name);
  }
}
