import 'package:flutter_bloc/flutter_bloc.dart';
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
    final result = await _profileRepository.getProfile();
    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (profile) => emit(ProfileLoaded(profile)),
    );
  }

  Future<void> updateProfile(ProfileEntity profile) async {
    // If currently loaded or save-succeeded/failed, we know the current profile
    ProfileEntity? currentProfile;
    if (state is ProfileLoaded) {
      currentProfile = (state as ProfileLoaded).profile;
    } else if (state is ProfileSaveSuccess) {
      currentProfile = (state as ProfileSaveSuccess).updatedProfile;
    }

    emit(ProfileSaving(currentProfile ?? profile));
    final result = await _profileRepository.updateProfile(profile);

    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (_) => emit(ProfileSaveSuccess(profile)),
    );
  }
}
