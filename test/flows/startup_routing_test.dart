import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:vital_up/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:vital_up/features/auth/data/repositories/auth_repository_impl.dart';

import 'support/fake_backend.dart';

/// The splash decision for a signed-in user: dashboard when onboarding is
/// done, health onboarding otherwise (`AuthRepository.hasCompletedOnboarding`,
/// which the splash page prefetches and maps an error to "done").

const _user = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

/// Secure storage stand-in for the per-user "onboarding completed" flag.
class _LocalFlags implements AuthLocalDataSource {
  final flags = <String, bool>{};

  @override
  Future<bool?> hasCompletedOnboarding(String userId) async => flags[userId];

  @override
  Future<void> setOnboardingCompleted(String userId, bool completed) async =>
      flags[userId] = completed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedRemote implements AuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Where the splash page goes for this answer (see SplashPage).
Future<String> _route(AuthRepositoryImpl repo) async {
  final done = await repo.hasCompletedOnboarding().catchError((_) => true);
  return done ? 'dashboard' : 'health-onboarding';
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final backend = FakeBackend();
  await Supabase.initialize(
    url: 'https://backend.test',
    publishableKey: 'publishable-key',
    httpClient: backend.client,
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      detectSessionInUri: false,
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
  final client = Supabase.instance.client;

  late _LocalFlags local;
  late AuthRepositoryImpl repo;

  setUp(() async {
    backend.tables.clear();
    backend.requests.clear();
    backend.offline = false;
    backend.hang = null;
    local = _LocalFlags();
    repo = AuthRepositoryImpl(
      remoteDataSource: _UnusedRemote(),
      localDataSource: local,
    );
    await FakeBackend.signIn(client, _user);
  });

  test('done on this phone: dashboard, without asking the server', () async {
    local.flags[_user] = true;
    expect(await _route(repo), 'dashboard');
    expect(backend.requests, isEmpty);
  });

  test('done on another phone: dashboard, and remembered here', () async {
    backend.tables['user_health_data'] = {
      _user: {'id': _user, 'onboarding_completed': true},
    };
    expect(await _route(repo), 'dashboard');
    expect(local.flags[_user], isTrue);
  });

  test('never onboarded: health onboarding', () async {
    expect(await _route(repo), 'health-onboarding');
    expect(local.flags[_user], isFalse);

    backend.tables['user_health_data'] = {
      _user: {'id': _user, 'onboarding_completed': false},
    };
    expect(await _route(repo), 'health-onboarding');
  });

  test('offline on first launch: a returning user is not sent back', () async {
    backend.offline = true;
    final watch = Stopwatch()..start();
    expect(await _route(repo), 'dashboard');
    // No 1 + 2 + 4 s automatic retries while the splash waits.
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('no network at all: answers without a request', () async {
    final offlineRepo = AuthRepositoryImpl(
      remoteDataSource: _UnusedRemote(),
      localDataSource: local,
      connectivity: _NoNetwork(),
    );
    // A request would hang until the timeout.
    backend.hang = Completer<void>();
    final watch = Stopwatch()..start();
    expect(await _route(offlineRepo), 'dashboard');
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    backend.hang!.complete();
  });

  test('offline after the server said "not done": onboarding', () async {
    expect(await _route(repo), 'health-onboarding');
    backend.offline = true;
    expect(await _route(repo), 'health-onboarding');
  });

  test(
    'a server that never answers gives up after the timeout',
    () async {
      backend.hang = Completer<void>();
      final watch = Stopwatch()..start();
      expect(await _route(repo), 'dashboard');
      expect(
        watch.elapsed,
        lessThan(
          AuthRepositoryImpl.onboardingCheckTimeout +
              const Duration(seconds: 2),
        ),
      );
      backend.hang!.complete();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('signed out: never the dashboard', () async {
    await client.auth.signOut();
    expect(await repo.hasCompletedOnboarding(), isFalse);
  });
}

class _NoNetwork extends ConnectivityService {
  @override
  bool get hasNetwork => false;
}
