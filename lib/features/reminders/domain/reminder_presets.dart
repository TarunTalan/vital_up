import 'package:vital_up/features/reminders/domain/entities/reminder.dart';

/// Built-in reminders. All start off; ids are stable so saved settings
/// survive app updates and new presets appear for existing users.
const reminderPresets = <Reminder>[
  Reminder(
    id: 'preset_activity',
    kind: ReminderKind.activity,
    title: 'Time to move',
    body: 'A short walk or workout keeps your streak going.',
    times: [ReminderTime(7, 30)],
    isPreset: true,
    route: 'activity-tracking',
  ),
  Reminder(
    id: 'preset_breakfast',
    kind: ReminderKind.meal,
    title: 'Log your breakfast',
    body: 'Snap or search what you ate this morning.',
    times: [ReminderTime(8, 30)],
    isPreset: true,
    route: 'food-scan',
  ),
  Reminder(
    id: 'preset_lunch',
    kind: ReminderKind.meal,
    title: 'Log your lunch',
    body: 'Keep your nutrition on track — log lunch now.',
    times: [ReminderTime(13, 0)],
    isPreset: true,
    route: 'food-scan',
  ),
  Reminder(
    id: 'preset_dinner',
    kind: ReminderKind.meal,
    title: 'Log your dinner',
    body: 'Finish the day strong — log dinner.',
    times: [ReminderTime(19, 30)],
    isPreset: true,
    route: 'food-scan',
  ),
  Reminder(
    id: 'preset_water',
    kind: ReminderKind.water,
    title: 'Drink some water',
    body: 'Stay hydrated — log a glass.',
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
    body: 'Take a moment for a quick mood check-in.',
    times: [ReminderTime(20, 0)],
    isPreset: true,
    route: 'stress-trends',
  ),
  Reminder(
    id: 'preset_weight',
    kind: ReminderKind.weight,
    title: 'Weekly weigh-in',
    body: 'Step on the scale and log it to see your trend.',
    times: [ReminderTime(7, 15)],
    weekdays: {DateTime.monday},
    isPreset: true,
    route: 'weight-trends',
  ),
  Reminder(
    id: 'preset_sleep',
    kind: ReminderKind.sleep,
    title: 'Time to wind down',
    body: 'Put the screens away — good sleep starts now.',
    times: [ReminderTime(22, 30)],
    isPreset: true,
    route: 'sleep-trends',
  ),
];

/// Turned on by the onboarding "Health reminders" choice.
const starterPresetIds = {
  'preset_water',
  'preset_breakfast',
  'preset_lunch',
  'preset_dinner',
  'preset_sleep',
};

/// Saved reminders with any presets they're missing, presets first in their
/// built-in order, then custom reminders in the order they were created.
List<Reminder> mergeWithPresets(List<Reminder> saved) {
  final byId = {for (final r in saved) r.id: r};
  return [
    for (final preset in reminderPresets) byId[preset.id] ?? preset,
    for (final r in saved)
      if (!r.isPreset) r,
  ];
}
