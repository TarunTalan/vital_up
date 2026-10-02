import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:vital_up/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/profile/data/profile_cache.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

class FakeRemote implements OnboardingRemoteDataSource {
  bool sent = true;
  Object? error;

  @override
  Future<bool> submitOnboardingData(OnboardingData data) async {
    if (error != null) throw error!;
    return sent;
  }
}

class FakeAuthLocal extends Fake implements AuthLocalDataSource {
  final flags = <String, bool>{};

  @override
  Future<void> setOnboardingCompleted(String userId, bool completed) async =>
      flags[userId] = completed;
}

void main() {
  late Directory dir;
  late CacheStore cache;
  late FakeRemote remote;
  late FakeAuthLocal authLocal;
  late OnboardingRepositoryImpl repo;

  const data = OnboardingData(
    fullName: 'Test User',
    weight: '80',
    weightUnit: 'kg',
    targetWeight: '154',
    targetWeightUnit: 'lb',
    calorieGoal: '1900',
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('onboarding_cache_test');
    cache = CacheStore(ConnectivityService(), directory: dir);
    remote = FakeRemote();
    authLocal = FakeAuthLocal();
    repo = OnboardingRepositoryImpl(
      remoteDataSource: remote,
      authLocalDataSource: authLocal,
      cacheStore: cache,
      currentUserId: () => 'u1',
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('queued (offline) submission succeeds and is kept locally', () async {
    await cache.write(
      ProfileCache.key('u1'),
      ProfileCache.encode(const ProfileEntity(id: 'u1', username: 'u', email: 'e')),
    );
    remote.sent = false;

    expect((await repo.submitOnboardingData(data)).isRight(), isTrue);
    expect(authLocal.flags['u1'], isTrue);

    final profile = (await cache.read<ProfileEntity>(
      ProfileCache.key('u1'),
      decode: ProfileCache.decode,
    ))!
        .value;
    expect(profile.fullName, 'Test User');
    expect(profile.weight, '80');
    expect(profile.dailyCalorieGoal, 1900);

    final target = await cache.read<Object?>(WeightService.targetCacheKey('u1'));
    expect(target!.value as double, closeTo(69.85, 0.01));
  });

  test('a server rejection is still reported', () async {
    remote.error = const ServerException(message: 'Database error');
    expect((await repo.submitOnboardingData(data)).isLeft(), isTrue);
    expect(authLocal.flags, isEmpty);
  });
}
