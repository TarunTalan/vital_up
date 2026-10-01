import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _profileRepository;

  ProfileCubit({
    required ProfileRepository profileRepository,
  })  : _profileRepository = profileRepository,
        super(ProfileInitial());

  Future<void> loadProfile() async {
    emit(ProfileLoading());
    final Either<Failure, ProfileEntity> result;
    try {
      result = await _profileRepository.getProfile().withLoadTimeout();
    } catch (_) {
      if (!isClosed) emit(const ProfileError(kLoadErrorMessage));
      return;
    }
    if (isClosed) return;
    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (profile) => emit(ProfileLoaded(profile)),
    );
  }

  /// The profile currently on screen, whatever state carries it.
  ProfileEntity? get currentProfile => switch (state) {
        ProfileLoaded(:final profile) => profile,
        ProfileSaveSuccess(:final updatedProfile) => updatedProfile,
        ProfileSaving(:final currentProfile) => currentProfile,
        ProfilePhotoUpdating(:final profile) => profile,
        ProfilePhotoUpdated(:final profile) => profile,
        ProfilePhotoFailed(:final profile) => profile,
        _ => null,
      };

  Future<void> uploadPhoto(File imageFile) async {
    final profile = currentProfile;
    if (profile == null || state is ProfilePhotoUpdating) return;

    emit(ProfilePhotoUpdating(profile));
    final result = await _profileRepository.uploadProfilePhoto(profile.id, imageFile);
    result.fold(
      (failure) => emit(ProfilePhotoFailed(profile, failure.message)),
      (url) => emit(ProfilePhotoUpdated(profile.copyWith(photoUrl: url))),
    );
  }

  Future<void> removePhoto() async {
    final profile = currentProfile;
    if (profile == null || state is ProfilePhotoUpdating) return;

    emit(ProfilePhotoUpdating(profile));
    final result = await _profileRepository.removeProfilePhoto(profile.id);
    result.fold(
      (failure) => emit(ProfilePhotoFailed(profile, failure.message)),
      (_) => emit(ProfilePhotoUpdated(
        profile.copyWith(clearPhotoUrl: true),
        removed: true,
      )),
    );
  }

  Future<void> updateProfile(ProfileEntity profile) async {
    emit(ProfileSaving(currentProfile ?? profile));
    final result = await _profileRepository.updateProfile(profile);

    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (_) => emit(ProfileSaveSuccess(profile)),
    );
  }
}
