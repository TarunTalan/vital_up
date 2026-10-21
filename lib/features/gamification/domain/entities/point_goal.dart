/// A goal that Arena points are scored against: without it, the matching
/// point rules ([sources]) can never be earned.
enum PointGoal {
  water('water', {'water_goal'}),
  calories('calorie', {'calorie_goal'}),
  activity('activity', {'daily_goal', 'weekly_goal'});

  /// Lower case, before "goal": "water goal".
  final String noun;

  /// `point_rules.source` values that need this goal.
  final Set<String> sources;

  const PointGoal(this.noun, this.sources);

  String get label => '$noun goal';

  /// The goal [source] needs, or null when it scores without one.
  static PointGoal? forSource(String source) {
    for (final goal in values) {
      if (goal.sources.contains(source)) return goal;
    }
    return null;
  }

  /// "A water goal earns points on days you hit it." / "Water and activity
  /// goals earn points on days you hit them."
  static String sentenceFor(Set<PointGoal> missing) {
    final names = [
      for (final g in values)
        if (missing.contains(g)) g.noun,
    ];
    if (names.isEmpty) return '';
    if (names.length == 1) {
      final noun = names.single;
      final article = 'aeiou'.contains(noun[0]) ? 'An' : 'A';
      return '$article $noun goal earns points on days you hit it.';
    }
    final list =
        '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return '${list[0].toUpperCase()}${list.substring(1)} goals earn points '
        'on days you hit them.';
  }
}
