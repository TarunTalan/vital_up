import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/sync/backup_sync.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';
import 'package:vital_up/core/sync/sync_service.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_repository_impl.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

import 'fake_backend.dart';

/// Loads Isar's native library from `isar_community_flutter_libs` (Windows
/// and Linux hosts). Returns why it couldn't (a skip reason), or null.
Future<String?> initIsarForTests() async {
  try {
    final root = _packageRoot('isar_community_flutter_libs');
    if (root == null) return 'isar_community_flutter_libs not found';
    final String file;
    if (Platform.isWindows) {
      file = '$root/windows/libisar.dll';
    } else if (Platform.isLinux) {
      file = '$root/linux/libisar.so';
    } else {
      return 'No Isar library for this host';
    }
    if (!File(file).existsSync()) return 'Missing $file';
    await Isar.initializeIsarCore(libraries: {Abi.current(): file});
    return null;
  } catch (e) {
    return 'Isar unavailable: $e';
  }
}

/// A package's folder, from the package config `flutter test` uses.
String? _packageRoot(String package) {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final json = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  for (final p in json['packages'] as List) {
    if (p is Map && p['name'] == package) {
      final uri = Uri.parse(p['rootUri'] as String);
      return (uri.isAbsolute ? uri : config.absolute.uri.resolveUri(uri))
          .toFilePath();
    }
  }
  return null;
}

/// Waits until [check] holds (work the app starts without awaiting it, such
/// as the profile weight write after logging a weight).
Future<void> eventually(
  FutureOr<bool> Function() check, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!await check()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// SharedPreferences for one simulated phone (the plugin's mock is a single
/// shared instance, so two phones need their own).
class MemoryPrefs implements SharedPreferences {
  final Map<String, Object> values = {};

  @override
  Set<String> getKeys() => values.keys.toSet();
  @override
  Object? get(String key) => values[key];
  @override
  bool? getBool(String key) => values[key] as bool?;
  @override
  int? getInt(String key) => values[key] as int?;
  @override
  double? getDouble(String key) => values[key] as double?;
  @override
  String? getString(String key) => values[key] as String?;
  @override
  bool containsKey(String key) => values.containsKey(key);
  @override
  List<String>? getStringList(String key) =>
      (values[key] as List?)?.cast<String>().toList();
  Future<bool> _set(String key, Object value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) => _set(key, value);
  @override
  Future<bool> setInt(String key, int value) => _set(key, value);
  @override
  Future<bool> setDouble(String key, double value) => _set(key, value);
  @override
  Future<bool> setString(String key, String value) => _set(key, value);
  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _set(key, List<String>.of(value));
  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;
  @override
  Future<void> reload() async {}
}

/// The OS network signal, switched by the test.
class FakeConnectivity implements Connectivity {
  FakeConnectivity(this._online);

  bool _online;
  final _changes = StreamController<List<ConnectivityResult>>.broadcast();

  List<ConnectivityResult> get _state => [
    _online ? ConnectivityResult.wifi : ConnectivityResult.none,
  ];

  /// Switches the network and lets listeners (the connectivity service)
  /// see it.
  Future<void> set(bool online) async {
    _online = online;
    _changes.add(_state);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _state;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;

  Future<void> close() => _changes.close();
}

class KgSettings implements SettingsRepository {
  @override
  Future<Either<Failure, SettingsEntity>> getSettings() async =>
      const Right(SettingsEntity());

  @override
  Future<Either<Failure, void>> saveSettings(SettingsEntity settings) async =>
      const Right(null);
}

/// One simulated phone: its own preferences, Isar, Drift, cache and
/// Supabase session, wired with the app's real services and sync engine,
/// talking to a shared [FakeBackend].
class TestDevice {
  final FakeBackend backend;
  final Directory dir;
  final MemoryPrefs prefs;
  final FakeConnectivity network;
  final ConnectivityService connectivity;
  final SupabaseClient client;
  final IsarService isarService;
  final AppDatabase drift;
  final CacheStore cache;
  final PendingWrites writes;
  final SyncService sync;
  final WaterIntakeService water;
  final WeightService weight;
  final ActivityRepositoryImpl activity;

  TestDevice._({
    required this.backend,
    required this.dir,
    required this.prefs,
    required this.network,
    required this.connectivity,
    required this.client,
    required this.isarService,
    required this.drift,
    required this.cache,
    required this.writes,
    required this.sync,
    required this.water,
    required this.weight,
    required this.activity,
  });

  static var _count = 0;

  /// [backups] builds the `user_backups` sources (settings, goals...) on
  /// this phone's preferences; none when omitted.
  static Future<TestDevice> create(
    FakeBackend backend, {
    bool online = true,
    MemoryPrefs? prefs,
    List<BackupSource> Function(SharedPreferences prefs)? backups,
  }) async {
    final name = 'device${_count++}';
    final dir = Directory.systemTemp.createTempSync('vitalup_$name');
    final store = prefs ?? MemoryPrefs();
    final network = FakeConnectivity(online);
    final connectivity = ConnectivityService(network);
    await connectivity.init();
    final client = backend.newClient();
    final isarService = IsarService()
      ..isar = await Isar.open(
        IsarService.schemas,
        directory: dir.path,
        name: name,
        inspector: false,
      );
    // Each phone has its own in-memory database.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final drift = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = CacheStore(
      connectivity,
      directory: Directory('${dir.path}/cache')..createSync(),
    );
    final writes = PendingWrites(store, connectivity);
    final sync = SyncService(
      client,
      store,
      [
        WaterSyncAdapter(isarService),
        SleepSyncAdapter(isarService),
        MealSyncAdapter(isarService),
        WeightSyncAdapter(isarService),
        ActivitySyncAdapter(drift),
        if (backups != null) BackupSyncAdapter(store, backups(store)),
      ],
      connectivity,
      writes,
    );
    // DI does the same: queued writes ask the sync engine to run.
    writes.attach(sync);
    return TestDevice._(
      backend: backend,
      dir: dir,
      prefs: store,
      network: network,
      connectivity: connectivity,
      client: client,
      isarService: isarService,
      drift: drift,
      cache: cache,
      writes: writes,
      sync: sync,
      water: WaterIntakeService(isarService, store, sync),
      weight: WeightService(
        isarService,
        client,
        KgSettings(),
        store,
        cache,
        writes,
        sync,
      ),
      activity: ActivityRepositoryImpl(drift, sync),
    );
  }

  Isar get isar => isarService.isar;

  String? get userId => client.auth.currentUser?.id;

  Future<void> signIn(String userId) => FakeBackend.signIn(client, userId);

  /// Waits for the debounced uploads and anything else in flight to finish.
  Future<void> settle() => sync.sync(pull: false);

  Future<void> dispose() async {
    sync.dispose();
    connectivity.dispose();
    await network.close();
    client.dispose();
    await drift.close();
    if (isar.isOpen) await isar.close(deleteFromDisk: true);
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
