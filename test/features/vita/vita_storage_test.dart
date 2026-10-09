import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/reminders/data/reminder_actions.dart';
import 'package:vital_up/features/vita/data/datasources/vita_local_datasource.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/presentation/cubit/vita_chat_cubit.dart';

void main() {
  final good = {'d': DateTime(2026, 1, 2).toIso8601String(), 'l': 2};
  final stored = jsonEncode([
    good,
    {'d': 'not a date', 'l': 3},
    {'d': DateTime(2026, 1, 3).toIso8601String(), 'l': 'x'},
    {'d': DateTime(2026, 1, 4).toIso8601String(), 'l': 9},
    'junk',
  ]);

  test('a bad stored check-in is skipped, the rest are kept', () async {
    SharedPreferences.setMockInitialValues({'vita_checkins_u': stored});
    final prefs = await SharedPreferences.getInstance();
    expect(VitaLocalDataSource(prefs).readCheckIns('u').single.level, 2);
    expect(readStoredCheckIns(prefs, 'u').single.level, 2);
  });

  test('broken JSON reads as empty instead of throwing', () async {
    SharedPreferences.setMockInitialValues({
      'vita_checkins_u': '{oops',
      'vita_scores_u': jsonEncode({'2026-01-01': 40, '2026-01-02': 'x'}),
    });
    final prefs = await SharedPreferences.getInstance();
    final local = VitaLocalDataSource(prefs);
    expect(local.readCheckIns('u'), isEmpty);
    expect(local.readScores('u'), {'2026-01-01': 40});
  });

  test('StressCheckIn.fromJson rejects bad entries', () {
    expect(StressCheckIn.fromJson(good).level, 2);
    expect(
      () => StressCheckIn.fromJson({'d': 'x', 'l': 1}),
      throwsFormatException,
    );
  });

  test('stored chat messages with odd bullets still load', () {
    final m = VitaMessage.fromJson({
      's': 'vita',
      't': 'Hi',
      'b': ['a', 1, null],
    });
    expect(m.bullets, ['a']);
  });

  test('chat messages are cleaned and capped before sending', () {
    expect(VitaChatCubit.cleanMessage('   '), isEmpty);
    expect(VitaChatCubit.cleanMessage('  hi   there '), 'hi there');
    expect(
      VitaChatCubit.cleanMessage('x' * 3000).length,
      InputLimits.chatMessage,
    );
  });
}
