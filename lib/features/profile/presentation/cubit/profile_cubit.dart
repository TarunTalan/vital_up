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

  /// Cached copy while fresh; [forceRefresh] (retry / pull-to-refresh)
  /// goes to the server.
  Future<void> loadProfile({bool forceRefresh = false}) async {
    // A failed refresh keeps showing what was there (pull-to-refresh
    // offline used to swap the whole page for an error).
    final previous = currentProfile;
    emit(ProfileLoading());
    final Either<Failure, ProfileEntity> result;
    try {
      result = await _profileRepository
          .getProfile(forceRefresh: forceRefresh)
          .withLoadTimeout();
    } catch (_) {
      if (!isClosed) _failLoad(kLoadErrorMessage, previous);
      return;
    }
    if (isClosed) return;
    result.fold(
      (failure) => _failLoad(failure.message, previous),
      (profile) => emit(ProfileLoaded(profile)),
    );
  }

  void _failLoad(String message, ProfileEntity? previous) {
    emit(ProfileError(message));
    if (previous != null) emit(ProfileLoaded(previous));
  }

  /// The profile currently on screen, whatever state carries it.
  ProfileEntity? get currentProfile => state.shownProfile;

  Future<void> uploadPhoto(File imageFile) async {
    final profile = currentProfile;
    if (profile == null || state is ProfilePhotoUpdating) return;

    emit(ProfilePhotoUpdating(profile));
    final result = await _profileRepository.uploadProfilePhoto(profile.id, imageFile);
    if (isClosed) return;
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
    if (isClosed) return;
    result.fold(
      (failure) => emit(ProfilePhotoFailed(profile, failure.message)),
      (_) => emit(ProfilePhotoUpdated(
        profile.copyWith(clearPhotoUrl: true),
        removed: true,
      )),
    );
  }

  Future<void> updateProfile(ProfileEntity profile) async {
    // One save at a time (double taps, a sheet saved while another runs).
    if (state is ProfileSaving) return;
    final previous = currentProfile ?? profile;
    emit(ProfileSaving(previous));
    Either<Failure, void> result;
    try {
      result = await _profileRepository.updateProfile(profile);
    } catch (e) {
      result = const Left(ServerFailure(_saveFailed));
    }
    if (isClosed) return;

    result.fold(
      (failure) {
        // Report the error, then keep showing the unsaved profile.
        emit(ProfileError(failure.message));
        emit(ProfileLoaded(previous));
      },
      (_) => emit(ProfileSaveSuccess(profile)),
    );
  }

  static const _saveFailed = "Couldn't save your profile. Try again.";
}
