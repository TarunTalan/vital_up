/// Kinds of session. The first five are tracked with GPS; the rest are
/// workouts without a route (gym, studio, pool, court), logged by time.
///
/// Stored by [name] in Drift and `activity_sessions.activity_type`: never
/// rename a value, and read stored names with [ActivityType.fromName] so a
/// type added by a newer app version shows as [other] instead of failing.
enum ActivityType {
  walk,
  run,
  cycle,
  trekking,
  climbing,
  strength,
  yoga,
  hiit,
  swimming,
  dance,
  sports,
  other;

  /// The type stored as [name], or [other] for a name this version doesn't
  /// know (written by a newer app on another device).
  static ActivityType fromName(String? name) =>
      values.asNameMap()[name] ?? ActivityType.other;

  /// Types a GPS workout can be started with.
  static List<ActivityType> get outdoor =>
      values.where((t) => t.isGpsBased).toList();

  /// Workouts without a route.
  static List<ActivityType> get workouts =>
      values.where((t) => !t.isGpsBased).toList();
}

extension ActivityTypeLabel on ActivityType {
  String get label {
    return switch (this) {
      ActivityType.walk => 'Walking',
      ActivityType.run => 'Running',
      ActivityType.cycle => 'Cycling',
      ActivityType.trekking => 'Trekking',
      ActivityType.climbing => 'Climbing',
      ActivityType.strength => 'Strength',
      ActivityType.yoga => 'Yoga',
      ActivityType.hiit => 'HIIT',
      ActivityType.swimming => 'Swimming',
      ActivityType.dance => 'Dance',
      ActivityType.sports => 'Sports',
      ActivityType.other => 'Other workout',
    };
  }

  /// Whether this activity is tracked with GPS (route, distance, pace).
  bool get isGpsBased {
    return switch (this) {
      ActivityType.walk ||
      ActivityType.run ||
      ActivityType.cycle ||
      ActivityType.trekking ||
      ActivityType.climbing => true,
      _ => false,
    };
  }

  /// Maximum GPS-reported speed that is considered realistic for this activity.
  /// Used to filter out GPS noise / teleport spikes. We use the GPS chip's
  /// Doppler-derived speed (not position-derived) so thresholds can be generous.
  /// Workouts without a route allow no distance, except swimming (pool and
  /// open-water distance from a watch).
  double get maxReasonableSpeedMetersPerSecond {
    return switch (this) {
      ActivityType.walk => 3.6, // ~13 km/h — brisk walk / slight jog
      ActivityType.run => 10.0, // ~36 km/h — elite sprint upper bound
      ActivityType.cycle => 22.0, // ~80 km/h — downhill / velodrome sprint
      ActivityType.trekking => 3.5, // ~12.6 km/h — trekking speed
      ActivityType.climbing => 2.0, // ~7.2 km/h — climbing speed
      ActivityType.swimming => 2.5, // ~9 km/h — above elite freestyle
      _ => 0,
    };
  }

  /// MET (Metabolic Equivalent of Task) value for this activity at moderate intensity.
  /// Used for duration-based calorie fallback when distance < 10 m, and for
  /// every workout without a route (2011 Compendium of Physical Activities).
  double get met {
    return switch (this) {
      ActivityType.walk => 3.8,
      ActivityType.run => 9.8,
      ActivityType.cycle => 7.5,
      ActivityType.trekking => 7.3,
      ActivityType.climbing => 9.0,
      ActivityType.strength => 5.0,
      ActivityType.yoga => 2.5,
      ActivityType.hiit => 8.0,
      ActivityType.swimming => 7.0,
      ActivityType.dance => 5.0,
      ActivityType.sports => 7.0,
      ActivityType.other => 4.0,
    };
  }

  /// Metabolic cost in kcal per kg per km, used in distance-based calorie calc.
  /// Values sourced from Margaria-Cavagna running economy and cycling studies.
  /// Zero for workouts without a route: their calories come from [met].
  double get kcalPerKgPerKm {
    return switch (this) {
      ActivityType.walk => 0.72, // Walking economy ~0.7–0.75 kcal/(kg·km)
      ActivityType.run => 1.04, // Running economy ~1.0–1.05 kcal/(kg·km)
      ActivityType.cycle =>
        0.38, // Cycling ~0.35–0.42 kcal/(kg·km) at moderate pace
      ActivityType.trekking =>
        0.90, // Trekking ~0.90 kcal/(kg·km) due to elevation
      ActivityType.climbing =>
        1.80, // Climbing ~1.80 kcal/(kg·km) due to steepness
      _ => 0,
    };
  }

  /// Helper to check if the activity is a slower, walking-like movement that requires EMA smoothing and low movement gates.
  bool get isSlowMovement {
    return this == ActivityType.walk ||
        this == ActivityType.trekking ||
        this == ActivityType.climbing;
  }
}
