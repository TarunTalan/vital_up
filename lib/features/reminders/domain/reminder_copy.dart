import 'package:vital_up/features/reminders/domain/entities/reminder.dart';

/// What a preset reminder's notification says: a few short, friendly
/// variants each, so the same words don't arrive every day. Plain and
/// calm: a hook title, one line of what to do, no emojis or "!".
/// Reminders the user wrote keep their own words.
const Map<String, List<(String, String)>> presetMessages = {
  'preset_activity': [
    ('Time to move', 'A short walk counts. Your legs will thank you.'),
    ('Up for a walk?', 'Ten minutes outside is a great start.'),
    ('Your steps are waiting', 'Start a quick walk, run or workout.'),
  ],
  'preset_breakfast': [
    ('Breakfast check', "What's on the plate? Snap it or search it."),
    ('Morning fuel', 'Log breakfast in a few seconds.'),
    ('First meal of the day', 'A quick photo is all it takes.'),
  ],
  'preset_lunch': [
    ("Lunch o'clock", 'Snap your plate before the first bite.'),
    ("What's for lunch?", 'Log it now, forget about it later.'),
    ('Midday refuel', "Keep today's totals honest. Log lunch."),
  ],
  'preset_dinner': [
    ('Dinner time', 'Log your plate and wrap up the day.'),
    ('Last meal of the day?', "A quick snap finishes today's log."),
    ("What's for dinner?", 'Log it and see how today added up.'),
  ],
  'preset_water': [
    ('Sip break', 'A glass of water, then back to it.'),
    ("Water o'clock", "Your body's asking for a glass."),
    ('Hydration check', 'When did you last have a glass?'),
    ('Top up', 'One more glass gets you closer to your goal.'),
    ('Stay fresh', 'Grab some water and log it.'),
  ],
  'preset_mood': [
    ("How's today feeling?", 'Take ten seconds to check in.'),
    ('Quick check-in', 'Calm, fine or stressed? Tap to log it.'),
    ('Pause for a moment', 'Note how you feel tonight.'),
  ],
  'preset_weight': [
    ('Weigh-in day', 'Step on, log it, watch your trend.'),
    ('Weekly check-in', 'One number a week shows the real trend.'),
  ],
  'preset_sleep': [
    ('Wind-down time', 'Screens down soon. Tap Going to bed when you turn in.'),
    ('Bedtime is calling', 'Tap Going to bed when the lights go off.'),
    ('Time to recharge', 'A good night starts now. Tap Going to bed.'),
  ],
  'preset_morning_sleep': [
    ('Good morning', 'See how you slept and confirm last night.'),
    ('Rise and shine', "Last night's sleep is ready to check."),
    ('How did you sleep?', 'Take a look and confirm your night.'),
  ],
};

/// Title and body for one firing of [reminder]. [slot] picks the variant
/// (the time of day and the day it was scheduled), so a water reminder
/// says something different each time it comes up. Without the
/// "Going to bed" button ([bedtimeAction] false: moved before 5 pm, signed
/// out) the text doesn't mention it.
(String title, String body) reminderMessage(
  Reminder reminder,
  int slot, {
  bool bedtimeAction = true,
}) {
  final variants = reminder.isPreset ? presetMessages[reminder.id] : null;
  if (variants == null || variants.isEmpty) {
    return (reminder.title, reminder.body);
  }
  final (title, body) = variants[slot.abs() % variants.length];
  if (!bedtimeAction && body.contains('Going to bed')) {
    return (title, 'Put the screens away and start winding down.');
  }
  return (title, body);
}
