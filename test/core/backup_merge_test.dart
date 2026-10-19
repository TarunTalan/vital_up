import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/sync/backup_sync.dart';

/// The SharedPreferences calls PrefsBackupSource and BackupSyncAdapter use,
/// one store per simulated phone.
class _MemoryPrefs implements SharedPreferences {
  final Map<String, Object> values = {};

  @override
  Object? get(String key) => values[key];

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `user_backups` with the migration's last-writer-wins trigger.
class _Server {
  final Map<String, Map<String, dynamic>> rows = {};

  void upsert(List<Map<String, dynamic>> batch) {
    for (final row in batch) {
      final old = rows[row['id']];
      if (old != null &&
          !DateTime.parse(row['changed_at'] as String)
              .isAfter(DateTime.parse(old['changed_at'] as String))) {
        continue;
      }
      rows[row['id'] as String] = Map.of(row);
    }
  }
}

const _checkIns = 'vita_checkins_{user}';
const _notes = 'activity_annotations';

class _Phone {
  final prefs = _MemoryPrefs();
  late final source = PrefsBackupSource(
    'stress',
    prefs,
    const [_checkIns, _notes],
    entryKeys: {_checkIns: checkInDayId, _notes: null},
  );
  late final adapter = BackupSyncAdapter(prefs, [source]);

  List<String> get days => [
    for (final c in jsonDecode(prefs.getString('vita_checkins_u1') ?? '[]')
        as List)
      (c as Map)['d'] as String,
  ];

  Map<String, dynamic> get notes =>
      jsonDecode(prefs.getString(_notes) ?? '{}') as Map<String, dynamic>;

  void checkIn(String day, int level) {
    final list = [
      ...jsonDecode(prefs.getString('vita_checkins_u1') ?? '[]') as List,
      {'d': '${day}T09:00:00.000', 'l': level},
    ];
    prefs.values['vita_checkins_u1'] = jsonEncode(list);
  }

  void note(String workout, String text) {
    prefs.values[_notes] = jsonEncode({
      ...notes,
      workout: {'sessionId': workout, 'note': text},
    });
  }

  /// One SyncService run for a [PullBeforePush] adapter: note edits, pull,
  /// then push.
  Future<void> sync(_Server server) async {
    await adapter.noteEdits('u1');
    await adapter.apply('u1', server.rows.values.toList());
    final pending = await adapter.pending('u1');
    server.upsert([for (final p in pending) p.row]);
    await adapter.markSynced('u1', [for (final p in pending) p.localKey]);
  }
}

void main() {
  test('check-ins made on two phones are both kept', () async {
    final server = _Server();
    final a = _Phone()..checkIn('2026-10-10', 2);
    final b = _Phone();
    await a.sync(server);
    await b.sync(server);

    a.checkIn('2026-10-12', 3); // Monday on the phone
    b.checkIn('2026-10-13', 4); // Tuesday on the tablet
    await b.sync(server);
    await a.sync(server);
    await b.sync(server);

    const all = [
      '2026-10-10T09:00:00.000',
      '2026-10-12T09:00:00.000',
      '2026-10-13T09:00:00.000',
    ];
    expect(a.days, all);
    expect(b.days, all);
  });

  test('notes for different workouts on two phones are both kept', () async {
    final server = _Server();
    final a = _Phone();
    final b = _Phone();
    await a.sync(server);
    await b.sync(server);

    a.note('w1', 'Easy run');
    b.note('w2', 'Hills');
    await a.sync(server);
    await b.sync(server);
    await a.sync(server);

    expect(a.notes.keys, unorderedEquals(['w1', 'w2']));
    expect(b.notes.keys, unorderedEquals(['w1', 'w2']));
  });

  test('an entry removed on one phone is not brought back', () async {
    final server = _Server();
    final a = _Phone()
      ..checkIn('2026-10-10', 2)
      ..checkIn('2026-10-11', 3);
    final b = _Phone();
    await a.sync(server);
    await b.sync(server);

    // A trims the old day while B adds one.
    a.prefs.values['vita_checkins_u1'] = jsonEncode([
      {'d': '2026-10-11T09:00:00.000', 'l': 3},
    ]);
    b.checkIn('2026-10-12', 1);
    await b.sync(server);
    await a.sync(server);
    await b.sync(server);

    const kept = ['2026-10-11T09:00:00.000', '2026-10-12T09:00:00.000'];
    expect(a.days, kept);
    expect(b.days, kept);
  });

  test('the same entry edited on both phones settles on one value', () async {
    final server = _Server();
    final a = _Phone()..note('w1', 'First');
    final b = _Phone();
    await a.sync(server);
    await b.sync(server);

    a.note('w1', 'From A');
    b.note('w1', 'From B');
    await b.sync(server);
    await a.sync(server);
    await b.sync(server);

    expect(a.notes['w1']['note'], 'From A');
    expect(b.notes['w1']['note'], 'From A');
  });

  test('an offline edit keeps the time it was made', () async {
    final server = _Server();
    final a = _Phone()..checkIn('2026-10-10', 2);
    await a.sync(server);

    a.checkIn('2026-10-11', 3);
    final before = DateTime.now().toUtc();
    await a.adapter.noteEdits('u1'); // A sync attempt with no network.
    final after = DateTime.now().toUtc();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final pending = await a.adapter.pending('u1');
    final at = DateTime.parse(pending.single.row['changed_at'] as String);
    expect(at.isBefore(before), isFalse);
    expect(at.isAfter(after), isFalse);
  });

  test('checkInDayId reads the day and refuses odd entries', () {
    expect(checkInDayId({'d': '2026-10-18T07:00:00.000', 'l': 2}), '2026-10-18');
    expect(checkInDayId({'l': 2}), isNull);
    expect(checkInDayId('x'), isNull);
  });
}
