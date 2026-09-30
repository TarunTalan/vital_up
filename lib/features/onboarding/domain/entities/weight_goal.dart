/// Primary objective chosen on the onboarding goal step.
enum GoalType {
  lose('lose'),
  maintain('maintain'),
  buildMuscle('build_muscle');

  final String id;
  const GoalType(this.id);

  static GoalType? fromId(String id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// How fast the user wants to change weight.
enum WeeklyPace {
  relaxed('relaxed', 0.25),
  normal('normal', 0.5),
  aggressive('aggressive', 1.0);

  final String id;
  final double kgPerWeek;
  const WeeklyPace(this.id, this.kgPerWeek);

  static WeeklyPace? fromId(String id) {
    for (final pace in values) {
      if (pace.id == id) return pace;
    }
    return null;
  }
}
