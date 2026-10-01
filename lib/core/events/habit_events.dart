import 'dart:async';

/// Something the user tracks; matches the reminder kinds.
enum Habit { water, meal, activity, mood, weight }

/// The user just logged [habit]. Reminders use this to stay quiet for the
/// rest of the day once it's done.
class HabitLogged {
  final Habit habit;

  /// For meals: 0 breakfast, 1 lunch, 2 dinner, 3 snack.
  final int? mealType;

  /// For water: today's goal is reached.
  final bool goalReached;

  const HabitLogged(this.habit, {this.mealType, this.goalReached = false});
}

/// App-wide stream of [HabitLogged] events (registered in get_it).
class HabitEvents {
  final _controller = StreamController<HabitLogged>.broadcast();

  Stream<HabitLogged> get stream => _controller.stream;

  void logged(HabitLogged event) => _controller.add(event);
}
