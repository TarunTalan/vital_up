import 'package:vital_up/features/reminders/domain/entities/reminder.dart';

/// Built-in reminders. All start off; ids are stable so saved settings
/// survive app updates and new presets appear for existing users.
const reminderPresets = <Reminder>[
  Reminder(
    id: 'preset_activity',
    kind: ReminderKind.activity,
    title: 'Time to move',
    body: 'A short walk counts. Your legs will thank you.',
    times: [ReminderTime(7, 30)],
    isPreset: true,
    route: 'activity-tracking',
  ),
  Reminder(
    id: 'preset_breakfast',
    kind: ReminderKind.meal,
    title: 'Log your breakfast',
    body: "What's on the plate? Snap it or search it.",
    times: [ReminderTime(8, 30)],
    isPreset: true,
    route: 'food-scan',
  ),
  Reminder(
    id: 'preset_lunch',
    kind: ReminderKind.meal,
    title: 'Log your lunch',
    body: 'Snap your plate before the first bite.',
    times: [ReminderTime(13, 0)],
    isPreset: true,
    route: 'food-scan',
  ),
  Reminder(
    id: 'preset_dinner',
    kind: ReminderKind.meal,
    title: 'Log your dinner',
    body: 'Log your plate and wrap up the day.',
    times: [ReminderTime(19, 30)],
    isPreset: true,
    route: 'food-scan',
  ),
  Reminder(
    id: 'preset_water',
    kind: ReminderKind.water,
    title: 'Drink some water',
    body: 'A glass of water, then back to it.',
    isPreset: true,
    route: 'water-trends',
    intervalMinutes: 120,
    windowStart: ReminderTime(9, 0),
    windowEnd: ReminderTime(21, 0),
  ),
  Reminder(
    id: 'preset_mood',
    kind: ReminderKind.mood,
    title: 'How are you feeling?',
    body: 'Take ten seconds to check in.',
    times: [ReminderTime(20, 0)],
    isPreset: true,
    route: 'stress-trends',
  ),
  Reminder(
    id: 'preset_weight',
    kind: ReminderKind.weight,
    title: 'Weekly weigh-in',
    body: 'Step on, log it, watch your trend.',
    times: [ReminderTime(7, 15)],
    weekdays: {DateTime.monday},
    isPreset: true,
    route: 'weight-trends',
  ),
  Reminder(
    id: 'preset_sleep',
    kind: ReminderKind.sleep,
    title: 'Time to wind down',
    body: 'Screens down soon. Tap Going to bed when you turn in.',
    times: [ReminderTime(22, 30)],
    isPreset: true,
    route: 'sleep-trends',
  ),
  Reminder(
    id: 'preset_morning_sleep',
    kind: ReminderKind.sleep,
    title: 'Good morning',
    body: 'See how you slept and confirm last night.',
    times: [ReminderTime(8, 0)],
    isPreset: true,
    // Opens Home, where the sleep card asks to confirm last night.
  ),
];

/// Turned on by the onboarding "Health reminders" choice.
const starterPresetIds = {
  'preset_water',
  'preset_breakfast',
  'preset_lunch',
  'preset_dinner',
  'preset_sleep',
  'preset_morning_sleep',
};

/// Saved reminders with any presets they're missing, presets first in their
/// built-in order, then custom reminders in the order they were created.
/// A preset's words always come from the app (users set only its times),
/// so new copy reaches reminders saved before it.
List<Reminder> mergeWithPresets(List<Reminder> saved) {
  final byId = {for (final r in saved) r.id: r};
  return [
    for (final preset in reminderPresets)
      byId[preset.id]?.copyWith(title: preset.title, body: preset.body) ??
          preset,
    for (final r in saved)
      if (!r.isPreset) r,
  ];
}
