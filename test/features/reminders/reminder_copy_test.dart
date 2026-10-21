import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/domain/reminder_copy.dart';
import 'package:vital_up/features/reminders/domain/reminder_presets.dart';

void main() {
  test('every preset has short, calm variants', () {
    for (final preset in reminderPresets) {
      final variants = presetMessages[preset.id];
      expect(variants, isNotNull, reason: preset.id);
      expect(variants!.length, greaterThanOrEqualTo(2), reason: preset.id);
      for (final (title, body) in variants) {
        expect(title.length, lessThanOrEqualTo(30), reason: title);
        expect(body.length, lessThanOrEqualTo(60), reason: body);
        expect('$title$body'.contains('!'), isFalse, reason: title);
        expect(
          RegExp(r'[^\x00-\x7F]').hasMatch('$title$body'),
          isFalse,
          reason: 'plain text only (no emojis or dashes): $title',
        );
      }
    }
  });

  test('variants rotate with the slot', () {
    final water = reminderPresets.firstWhere((r) => r.id == 'preset_water');
    final seen = {
      for (var slot = 0; slot < 10; slot++) reminderMessage(water, slot),
    };
    expect(seen.length, presetMessages['preset_water']!.length);
  });

  test('evening sleep text mentions Going to bed only with the button', () {
    final sleep = reminderPresets.firstWhere((r) => r.id == 'preset_sleep');
    for (var slot = 0; slot < 3; slot++) {
      expect(reminderMessage(sleep, slot).$2, contains('Going to bed'));
      expect(
        reminderMessage(sleep, slot, bedtimeAction: false).$2,
        isNot(contains('Going to bed')),
      );
    }
  });

  test('a reminder the user wrote keeps its words', () {
    const custom = Reminder(
      id: 'custom_1',
      kind: ReminderKind.custom,
      title: 'Stretch',
      body: 'Neck and shoulders',
    );
    expect(reminderMessage(custom, 3), ('Stretch', 'Neck and shoulders'));
  });

  test('saved presets pick up new copy, keep their times', () {
    final old = reminderPresets
        .firstWhere((r) => r.id == 'preset_lunch')
        .copyWith(
          title: 'Log your lunch',
          body: 'Old text from an earlier version.',
          times: const [ReminderTime(12, 15)],
          enabled: true,
        );
    final merged = mergeWithPresets([
      old,
    ]).firstWhere((r) => r.id == 'preset_lunch');
    expect(merged.body, isNot(old.body));
    expect(merged.times, const [ReminderTime(12, 15)]);
    expect(merged.enabled, isTrue);
  });
}
