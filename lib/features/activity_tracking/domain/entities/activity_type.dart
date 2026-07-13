enum ActivityType {
  walk,
  run,
  cycle,
  trekking,
  climbing,
}

extension ActivityTypeLabel on ActivityType {
  String get label {
    return switch (this) {
      ActivityType.walk => 'Walking',
      ActivityType.run => 'Running',
      ActivityType.cycle => 'Cycling',
      ActivityType.trekking => 'Trekking',
      ActivityType.climbing => 'Climbing',
    };
  }

  /// Maximum GPS-reported speed that is considered realistic for this activity.
  /// Used to filter out GPS noise / teleport spikes. We use the GPS chip's
  /// Doppler-derived speed (not position-derived) so thresholds can be generous.
  double get maxReasonableSpeedMetersPerSecond {
    return switch (this) {
      ActivityType.walk => 3.6,   // ~13 km/h — brisk walk / slight jog
      ActivityType.run => 10.0,   // ~36 km/h — elite sprint upper bound
      ActivityType.cycle => 22.0, // ~80 km/h — downhill / velodrome sprint
      ActivityType.trekking => 3.5, // ~12.6 km/h — trekking speed
      ActivityType.climbing => 2.0, // ~7.2 km/h — climbing speed
    };
  }

  /// MET (Metabolic Equivalent of Task) value for this activity at moderate intensity.
  /// Used for duration-based calorie fallback when distance < 10 m.
  double get met {
    return switch (this) {
      ActivityType.walk => 3.8,
      ActivityType.run => 9.8,
      ActivityType.cycle => 7.5,
      ActivityType.trekking => 7.3,
      ActivityType.climbing => 9.0,
    };
  }

  /// Metabolic cost in kcal per kg per km, used in distance-based calorie calc.
  /// Values sourced from Margaria-Cavagna running economy and cycling studies.
  double get kcalPerKgPerKm {
    return switch (this) {
      ActivityType.walk => 0.72,  // Walking economy ~0.7–0.75 kcal/(kg·km)
      ActivityType.run => 1.04,   // Running economy ~1.0–1.05 kcal/(kg·km)
      ActivityType.cycle => 0.38, // Cycling ~0.35–0.42 kcal/(kg·km) at moderate pace
      ActivityType.trekking => 0.90, // Trekking ~0.90 kcal/(kg·km) due to elevation
      ActivityType.climbing => 1.80, // Climbing ~1.80 kcal/(kg·km) due to steepness
    };
  }

  /// Helper to check if the activity is a slower, walking-like movement that requires EMA smoothing and low movement gates.
  bool get isSlowMovement {
    return this == ActivityType.walk ||
        this == ActivityType.trekking ||
        this == ActivityType.climbing;
  }
}


