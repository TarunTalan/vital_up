import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:isar_community/isar.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vital_up/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

// Custom Fake classes for Isar and RemoteDataSource mocking

class FakeLogger extends Fake implements Logger {
  final List<String> errors = [];
  final List<String> infos = [];

  @override
  void e(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    errors.add(message.toString());
  }

  @override
  void i(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    infos.add(message.toString());
  }
}

class FakeProfileRemoteDataSource extends Fake implements ProfileRemoteDataSource {
  ProfileEntity? getProfileResult;
  bool shouldThrow = false;
  String exceptionMessage = 'Server error';
  ProfileEntity? lastUpdatedProfile;

  @override
  Future<ProfileEntity> getProfile() async {
    if (shouldThrow) {
      throw ServerException(message: exceptionMessage);
    }
    if (getProfileResult == null) {
      throw const ServerException(message: 'No profile data found');
    }
    return getProfileResult!;
  }

  @override
  Future<void> updateProfile(ProfileEntity profile) async {
    if (shouldThrow) {
      throw ServerException(message: exceptionMessage);
    }
    lastUpdatedProfile = profile;
  }
}

class FakeQueryBuilder extends Fake implements QueryBuilder<UserProfileCache, UserProfileCache, QWhere> {
  final List<UserProfileCache> items;
  FakeQueryBuilder(this.items);

  @override
  List<UserProfileCache> findAllSync() {
    return items;
  }
}

class FakeIsarCollection extends Fake implements IsarCollection<UserProfileCache> {
  final List<UserProfileCache> items = [];

  @override
  Future<int> putBySupabaseId(UserProfileCache object) async {
    items.removeWhere((e) => e.supabaseId == object.supabaseId);
    items.add(object);
    return 1;
  }

  @override
  QueryBuilder<UserProfileCache, UserProfileCache, QWhere> where() {
    return FakeQueryBuilder(items);
  }
}

class FakeIsar extends Fake implements Isar {
  final FakeIsarCollection userProfileCollection = FakeIsarCollection();

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false}) async {
    return await callback();
  }

  @override
  IsarCollection<T> collection<T>() {
    if (T == UserProfileCache) {
      return userProfileCollection as IsarCollection<T>;
    }
    throw Exception('No collection registered for type $T');
  }
}

class FakeIsarService extends Fake implements IsarService {
  final FakeIsar fakeIsar = FakeIsar();

  @override
  Isar get isar => fakeIsar;
}

void main() {
  late ProfileRepositoryImpl repository;
  late FakeProfileRemoteDataSource fakeRemoteDataSource;
  late FakeIsarService fakeIsarService;
  late FakeLogger fakeLogger;

  setUp(() {
    fakeRemoteDataSource = FakeProfileRemoteDataSource();
    fakeIsarService = FakeIsarService();
    fakeLogger = FakeLogger();
    repository = ProfileRepositoryImpl(
      remoteDataSource: fakeRemoteDataSource,
      isarService: fakeIsarService,
      logger: fakeLogger,
    );
  });

  const tProfile = ProfileEntity(
    id: 'user123',
    username: 'testuser',
    email: 'test@example.com',
    fullName: 'Test User',
    dob: '15081995',
    gender: 'Male',
    weight: '80',
    weightUnit: 'kg',
    height: '180',
    heightUnit: 'cm',
    oxygenLevel: '99',
    healthConditions: 'None',
    allergies: 'None',
    medicines: 'None',
    smokes: 'No',
    bloodPressureTop: '120',
    bloodPressureBottom: '80',
    bpm: '70',
    activity: 'Sedentary',
    sleep: '7',
    photoUrl: 'https://example.com/avatar.png',
  );

  group('getProfile', () {
    test('should return remote profile and save it to local Isar cache on success', () async {
      fakeRemoteDataSource.getProfileResult = tProfile;

      final result = await repository.getProfile();

      expect(result, equals(const Right(tProfile)));
      // Verify local cache is populated
      final cachedProfile = fakeIsarService.fakeIsar.userProfileCollection.items.first;
      expect(cachedProfile.supabaseId, equals(tProfile.id));
      expect(cachedProfile.username, equals(tProfile.username));
      expect(cachedProfile.displayName, equals(tProfile.fullName));
    });

    test('should return cached profile when remote fetch fails and cache has data', () async {
      // 1. Populate the local cache
      final cacheItem = UserProfileCache()
        ..supabaseId = 'user123'
        ..username = 'cached_username'
        ..email = 'cached@example.com'
        ..displayName = 'Cached Name'
        ..photoUrl = 'https://example.com/cached.png'
        ..lastSyncedAt = DateTime.now();
      await fakeIsarService.fakeIsar.userProfileCollection.putBySupabaseId(cacheItem);

      // 2. Set remote datasource to throw an exception
      fakeRemoteDataSource.shouldThrow = true;
      fakeRemoteDataSource.exceptionMessage = 'SocketException: failed host lookup';

      final result = await repository.getProfile();

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Should have returned Right with cached profile'),
        (profile) {
          expect(profile.id, equals('user123'));
          expect(profile.username, equals('cached_username'));
          expect(profile.fullName, equals('Cached Name'));
          expect(profile.photoUrl, equals('https://example.com/cached.png'));
          // Other physical/health fields should be empty on fallback
          expect(profile.weight, isEmpty);
        },
      );
      expect(fakeLogger.infos, isNotEmpty);
    });

    test('should return ServerFailure when remote fetch fails and cache is empty', () async {
      fakeRemoteDataSource.shouldThrow = true;
      fakeRemoteDataSource.exceptionMessage = 'Some database timeout';

      final result = await repository.getProfile();

      expect(result, equals(const Left(ServerFailure('An unexpected error occurred. Please try again.'))));
      expect(fakeLogger.errors, isNotEmpty);
    });

    test('should map socket/network exception to user friendly message', () async {
      fakeRemoteDataSource.shouldThrow = true;
      fakeRemoteDataSource.exceptionMessage = 'SocketException: Network connection failed';

      final result = await repository.getProfile();

      expect(result, equals(const Left(ServerFailure('No internet connection. Please check your network settings.'))));
    });
  });

  group('updateProfile', () {
    test('should call remote datasource and update local cache on success', () async {
      final result = await repository.updateProfile(tProfile);

      expect(result, equals(const Right(null)));
      expect(fakeRemoteDataSource.lastUpdatedProfile, equals(tProfile));

      // Verify cache update
      final cachedProfile = fakeIsarService.fakeIsar.userProfileCollection.items.first;
      expect(cachedProfile.supabaseId, equals(tProfile.id));
      expect(cachedProfile.displayName, equals(tProfile.fullName));
    });

    test('should return ServerFailure when remote update fails', () async {
      fakeRemoteDataSource.shouldThrow = true;
      fakeRemoteDataSource.exceptionMessage = 'PostgrestException: unique key constraint';

      final result = await repository.updateProfile(tProfile);

      expect(result, equals(const Left(ServerFailure('Database operation failed. Please try again.'))));
    });
  });
}
