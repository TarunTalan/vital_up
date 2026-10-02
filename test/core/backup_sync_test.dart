import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/sync/backup_sync.dart';

/// Just the string storage BackupSyncAdapter uses for its state, so each
/// simulated phone gets its own.
class _MemoryPrefs implements SharedPreferences {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Source implements BackupSource {
  Object? data;
  int restores = 0;

  _Source(this.data);

  @override
  String get kind => 'goals';

  @override
  Future<Object?> export(String userId) async => data;

  @override
  Future<void> restore(String userId, Object? data) async {
    restores++;
    this.data = data;
  }
}

/// `user_backups` with the migration's last-writer-wins trigger.
class _Server {
  final Map<String, Map<String, dynamic>> rows = {};
  var _clock = 0;

  void upsert(List<Map<String, dynamic>> batch) {
    for (final row in batch) {
      final old = rows[row['id']];
      if (old != null &&
          !DateTime.parse(row['changed_at'] as String)
              .isAfter(DateTime.parse(old['changed_at'] as String))) {
        continue;
      }
      // jsonb reorders keys; the adapter must not care.
      final data = row['data'];
      rows[row['id'] as String] = {
        ...row,
        'data': data is Map ? Map.fromEntries(data.entries.toList().reversed) : data,
        'updated_at': _clock++,
      };
    }
  }
}

class _Phone {
  final source = _Source(null);
  late final adapter = BackupSyncAdapter(_MemoryPrefs(), [source]);

  _Phone(Object? data) {
    source.data = data;
  }

  /// One SyncService run: push, then pull everything.
  Future<void> sync(_Server server) async {
    final pending = await adapter.pending('u1');
    server.upsert([for (final p in pending) p.row]);
    await adapter.markSynced('u1', [for (final p in pending) p.localKey]);
    await adapter.apply('u1', server.rows.values.toList());
  }
}

void main() {
  const defaults = {'water': 2500, 'steps': 8000};
  const real = {'water': 3000, 'steps': 12000};

  test('canonical JSON ignores key order', () {
    expect(
      canonicalJson({'b': 1, 'a': {'d': 2, 'c': 3}}),
      canonicalJson({'a': {'c': 3, 'd': 2}, 'b': 1}),
    );
  });

  test('first phone backs up its data', () async {
    final server = _Server();
    await _Phone(real).sync(server);
    expect(server.rows['u1:goals']?['data'], real);
  });

  test('a new phone gets the backup instead of overwriting it', () async {
    final server = _Server();
    await _Phone(real).sync(server);

    final newPhone = _Phone(defaults);
    await newPhone.sync(server);

    expect(newPhone.source.data, real);
    expect(server.rows['u1:goals']?['data'], real);
  });

  test('an edit on one phone reaches the other', () async {
    final server = _Server();
    final a = _Phone(real);
    final b = _Phone(defaults);
    await a.sync(server);
    await b.sync(server);

    b.source.data = {'water': 3500, 'steps': 12000};
    await b.sync(server);
    await a.sync(server);

    expect(a.source.data, {'water': 3500, 'steps': 12000});
  });

  test('nothing is uploaded or restored when nothing changed', () async {
    final server = _Server();
    final phone = _Phone(real);
    await phone.sync(server);
    final restores = phone.source.restores;

    expect(await phone.adapter.pending('u1'), isEmpty);
    await phone.sync(server);
    expect(phone.source.restores, restores);
  });

  test('an unsent local edit is not replaced by an older backup', () async {
    final server = _Server();
    final a = _Phone(real);
    await a.sync(server);

    // Edited offline: noticed by a push attempt that never reached the server.
    a.source.data = {'water': 4000, 'steps': 12000};
    await a.adapter.pending('u1');
    await a.adapter.apply('u1', server.rows.values.toList());

    expect(a.source.data, {'water': 4000, 'steps': 12000});
  });
}
