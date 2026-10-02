import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';

// Custom Fake class for ProfileRepository mocking

class FakeProfileRepository implements ProfileRepository {
  Either<Failure, ProfileEntity>? getProfileResult;
  Either<Failure, void>? updateProfileResult;
  ProfileEntity? lastUpdatedProfile;
  int getProfileCallCount = 0;
  int updateProfileCallCount = 0;

  @override
  Future<Either<Failure, ProfileEntity>> getProfile({bool forceRefresh = false}) async {
    getProfileCallCount++;
    return getProfileResult ?? const Left(ServerFailure('Error fetching profile'));
  }

  @override
  Future<Either<Failure, void>> updateProfile(ProfileEntity profile) async {
    updateProfileCallCount++;
    lastUpdatedProfile = profile;
    return updateProfileResult ?? const Right(null);
  }

  Either<Failure, String>? uploadPhotoResult;
  Either<Failure, void>? removePhotoResult;

  @override
  Future<Either<Failure, String>> uploadProfilePhoto(String userId, File imageFile) async =>
      uploadPhotoResult ?? const Right('https://example.com/avatar.jpg');

  @override
  Future<Either<Failure, void>> removeProfilePhoto(String userId) async =>
      removePhotoResult ?? const Right(null);
}

void main() {
  late ProfileCubit cubit;
  late FakeProfileRepository fakeRepository;

  setUp(() {
    fakeRepository = FakeProfileRepository();
    cubit = ProfileCubit(profileRepository: fakeRepository);
  });

  tearDown(() {
    cubit.close();
  });

  const tProfile = ProfileEntity(
    id: 'user123',
    username: 'testuser',
    email: 'test@example.com',
    fullName: 'Test User',
  );

  test('initial state should be ProfileInitial', () {
    expect(cubit.state, equals(ProfileInitial()));
  });

  group('loadProfile', () {
    test('should emit [ProfileLoading, ProfileLoaded] when fetching remote profile succeeds', () async {
      fakeRepository.getProfileResult = const Right(tProfile);

      final expectedStates = [
        ProfileLoading(),
        const ProfileLoaded(tProfile),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadProfile();
      expect(fakeRepository.getProfileCallCount, equals(1));
    });

    test('should emit [ProfileLoading, ProfileError] when fetching remote profile fails', () async {
      fakeRepository.getProfileResult = const Left(ServerFailure('Connection error'));

      final expectedStates = [
        ProfileLoading(),
        const ProfileError('Connection error'),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadProfile();
      expect(fakeRepository.getProfileCallCount, equals(1));
    });
  });

  group('updateProfile', () {
    test('should emit [ProfileSaving, ProfileSaveSuccess] when updating profile succeeds', () async {
      fakeRepository.updateProfileResult = const Right(null);

      final expectedStates = [
        const ProfileSaving(tProfile),
        const ProfileSaveSuccess(tProfile),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.updateProfile(tProfile);
      expect(fakeRepository.updateProfileCallCount, equals(1));
      expect(fakeRepository.lastUpdatedProfile, equals(tProfile));
    });

    test('should emit [ProfileSaving, ProfileError] when updating profile fails', () async {
      fakeRepository.updateProfileResult = const Left(ServerFailure('Database error'));

      final expectedStates = [
        const ProfileSaving(tProfile),
        const ProfileError('Database error'),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.updateProfile(tProfile);
      expect(fakeRepository.updateProfileCallCount, equals(1));
    });

    test('ProfileSaving state should contain current profile if cubit was already loaded', () async {
      // 1. Load the profile first
      fakeRepository.getProfileResult = const Right(tProfile);
      await cubit.loadProfile();
      expect(cubit.state, equals(const ProfileLoaded(tProfile)));

      // 2. Perform update
      final updatedProfile = tProfile.copyWith(fullName: 'Updated Name');
      fakeRepository.updateProfileResult = const Right(null);

      final expectedStates = [
        const ProfileSaving(tProfile), // should use the last loaded profile as currentProfile
        ProfileSaveSuccess(updatedProfile),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.updateProfile(updatedProfile);
    });
  });

  group('profile photo', () {
    const profile = ProfileEntity(
      id: 'user-1',
      username: 'vita',
      email: 'vita@example.com',
      fullName: 'Vita User',
      photoUrl: 'https://example.com/old.jpg',
    );

    setUp(() => fakeRepository.getProfileResult = const Right(profile));

    test('upload emits updating then updated with the new URL', () async {
      await cubit.loadProfile();
      final states = <ProfileState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.uploadPhoto(File('avatar.jpg'));
      await Future<void>.delayed(Duration.zero); // let stream events deliver
      await sub.cancel();

      expect(states.first, isA<ProfilePhotoUpdating>());
      final updated = states.last as ProfilePhotoUpdated;
      expect(updated.profile.photoUrl, 'https://example.com/avatar.jpg');
      expect(updated.removed, isFalse);
    });

    test('failed upload keeps the profile and reports the error', () async {
      fakeRepository.uploadPhotoResult = const Left(ServerFailure('Upload failed'));
      await cubit.loadProfile();

      await cubit.uploadPhoto(File('avatar.jpg'));

      final failed = cubit.state as ProfilePhotoFailed;
      expect(failed.message, 'Upload failed');
      expect(failed.profile.photoUrl, profile.photoUrl);
    });

    test('remove clears the photo URL', () async {
      await cubit.loadProfile();

      await cubit.removePhoto();

      final updated = cubit.state as ProfilePhotoUpdated;
      expect(updated.profile.photoUrl, isNull);
      expect(updated.removed, isTrue);
    });
  });
}
