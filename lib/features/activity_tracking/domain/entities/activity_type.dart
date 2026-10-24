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
  ///
  /// Generous on purpose: a fix above it is dropped, so someone who breaks
  /// into a jog with Walking picked must not lose that part of the route.
  double get maxReasonableSpeedMetersPerSecond {
    return switch (this) {
      ActivityType.walk => 5.0, // ~18 km/h — walk breaking into a jog
      ActivityType.run => 10.0, // ~36 km/h — elite sprint upper bound
      ActivityType.cycle => 22.0, // ~80 km/h — downhill / velodrome sprint
      ActivityType.trekking => 5.0, // ~18 km/h — jogging down a trail
      ActivityType.climbing => 3.0, // ~11 km/h — scrambling / descending
      ActivityType.swimming => 2.5, // ~9 km/h — above elite freestyle
      _ => 0,
    };
  }

  /// MET (Metabolic Equivalent of Task) value for this activity at moderate
  /// intensity (2011 Compendium of Physical Activities). Every workout
  /// without a route uses it; of the GPS types only climbing does (its
  /// effort is vertical, not distance), see `estimateGpsCalories`.
  double get met {
    return switch (this) {
      ActivityType.walk => 3.5,
      ActivityType.run => 9.8,
      ActivityType.cycle => 7.5,
      ActivityType.trekking => 6.0,
      ActivityType.climbing => 8.0,
      ActivityType.strength => 5.0,
      ActivityType.yoga => 2.5,
      ActivityType.hiit => 8.0,
      ActivityType.swimming => 7.0,
      ActivityType.dance => 5.0,
      ActivityType.sports => 7.0,
      ActivityType.other => 4.0,
    };
  }

  /// Energy for moving one km on the flat, on top of resting, in kcal per
  /// kg (ACSM metabolic equations: walking 0.1 and running 0.2 ml O2 per
  /// kg per metre, 5 kcal per litre O2). Zero where calories come from
  /// [met] alone: workouts without a route, and climbing.
  double get kcalPerKgPerKm {
    return switch (this) {
      ActivityType.walk => 0.5, // 5 km/h -> 3.5 MET
      ActivityType.run => 1.0, // 10 km/h -> 11 MET
      // Fits the Compendium's speed bands (19-22 km/h: 8 MET).
      ActivityType.cycle => 0.35,
      // Walking on trails costs about 1.5x the road (Pandolf terrain factor).
      ActivityType.trekking => 0.75,
      _ => 0,
    };
  }

  /// Energy for climbing one metre, in kcal per kg (ACSM grade terms:
  /// walking 1.8 and running 0.9 ml O2 per kg per vertical metre; cycling
  /// is the lift work at ~24% efficiency).
  double get kcalPerKgPerClimbMeter {
    return switch (this) {
      ActivityType.walk || ActivityType.trekking => 0.009,
      ActivityType.run => 0.0045,
      ActivityType.cycle => 0.0098,
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
