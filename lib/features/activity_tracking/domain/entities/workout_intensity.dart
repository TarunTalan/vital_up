/// How hard a workout without a route felt, chosen when it is saved. Scales
/// the calorie estimate (the activity's MET is for moderate effort).
///
/// Stored by [name] (Drift `intensity`, synced inside the session data):
/// never rename a value.
enum WorkoutIntensity {
  light,
  moderate,
  hard;

  String get label => switch (this) {
    WorkoutIntensity.light => 'Light',
    WorkoutIntensity.moderate => 'Moderate',
    WorkoutIntensity.hard => 'Hard',
  };

  /// Multiplier on the activity's moderate MET.
  double get metFactor => switch (this) {
    WorkoutIntensity.light => 0.7,
    WorkoutIntensity.moderate => 1.0,
    WorkoutIntensity.hard => 1.3,
  };

  /// The intensity stored as [name], or null (GPS sessions have none; a
  /// value from a newer app version is dropped rather than guessed).
  static WorkoutIntensity? fromName(String? name) =>
      name == null ? null : values.asNameMap()[name];
}
