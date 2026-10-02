import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vital_up/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

class FakeRemote implements ProfileRemoteDataSource {
  ProfileEntity profile;
  Object? getError;
  Object? updateError;
  bool sent = true;
  int getCalls = 0;
  ProfileEntity? lastPrevious;

  FakeRemote(this.profile);

  @override
  Future<ProfileEntity> getProfile() async {
    getCalls++;
    if (getError != null) throw getError!;
    return profile;
  }

  @override
  Future<bool> updateProfile(ProfileEntity profile, {ProfileEntity? previous}) async {
    lastPrevious = previous;
    if (updateError != null) throw updateError!;
    return sent;
  }

  @override
  Future<String> uploadProfilePhoto(String userId, File imageFile) async =>
      throw const SocketException('Failed host lookup');

  @override
  Future<void> removeProfilePhoto(String userId) async {}
}

void main() {
  const tProfile = ProfileEntity(
    id: 'user123',
    username: 'testuser',
    email: 'test@example.com',
    fullName: 'Test User',
    weight: '70',
    bloodPressureTop: '120',
    allergies: 'Peanuts',
    dailyCalorieGoal: 2100,
  );

  late Directory dir;
  late FakeRemote remote;
  late ProfileRepositoryImpl repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('profile_cache_test');
    remote = FakeRemote(tProfile);
    repo = ProfileRepositoryImpl(
      remoteDataSource: remote,
      // Not opened: the Isar mirror is best effort and skipped in tests.
      isarService: IsarService(),
      cacheStore: CacheStore(ConnectivityService(), directory: dir),
      currentUserId: () => 'user123',
      logger: Logger(level: Level.off),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('serves a fresh cached profile without another request', () async {
    expect((await repo.getProfile()).getOrElse(() => throw 'x'), tProfile);
    expect((await repo.getProfile()).getOrElse(() => throw 'x'), tProfile);
    expect(remote.getCalls, 1);
  });

  test('forceRefresh asks the server again', () async {
    await repo.getProfile();
    await repo.getProfile(forceRefresh: true);
    expect(remote.getCalls, 2);
  });

  test('offline refresh falls back to the full cached profile', () async {
    await repo.getProfile();
    remote.getError = const SocketException('Failed host lookup');
    final result = await repo.getProfile(forceRefresh: true);
    // All health fields survive, not just the basics.
    expect(result.getOrElse(() => throw 'x'), tProfile);
  });

  test('offline with nothing cached reports no connection', () async {
    remote.getError = const SocketException('Failed host lookup');
    final result = await repo.getProfile();
    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f.message, contains('No internet connection')),
      (_) {},
    );
  });

  test('edits show immediately even when the write is queued', () async {
    await repo.getProfile();
    remote.sent = false; // offline: queued
    final edited = tProfile.copyWith(weight: '68', allergies: 'None');

    expect((await repo.updateProfile(edited)).isRight(), isTrue);
    expect(remote.lastPrevious, tProfile);
    expect((await repo.getProfile()).getOrElse(() => throw 'x'), edited);
    expect(remote.getCalls, 1);
  });

  test('a rejected edit is rolled back in the cache', () async {
    await repo.getProfile();
    remote.updateError = const ServerException(message: 'That username is taken');

    final result = await repo.updateProfile(tProfile.copyWith(username: 'taken'));
    expect(result.isLeft(), isTrue);
    expect((await repo.getProfile()).getOrElse(() => throw 'x'), tProfile);
  });

  test('photo upload offline fails with a clear message', () async {
    final result = await repo.uploadProfilePhoto('user123', File('a.jpg'));
    result.fold(
      (f) => expect(f.message, contains("You're offline")),
      (_) => fail('expected failure'),
    );
  });
}
