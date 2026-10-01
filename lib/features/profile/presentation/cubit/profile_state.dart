import 'package:equatable/equatable.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final ProfileEntity profile;

  const ProfileLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ProfileSaving extends ProfileState {
  final ProfileEntity currentProfile;

  const ProfileSaving(this.currentProfile);

  @override
  List<Object?> get props => [currentProfile];
}

class ProfileSaveSuccess extends ProfileState {
  final ProfileEntity updatedProfile;

  const ProfileSaveSuccess(this.updatedProfile);

  @override
  List<Object?> get props => [updatedProfile];
}

/// A profile photo upload / removal is in progress.
class ProfilePhotoUpdating extends ProfileState {
  final ProfileEntity profile;

  const ProfilePhotoUpdating(this.profile);

  @override
  List<Object?> get props => [profile];
}

/// The photo changed; [profile] carries the new (or cleared) photo URL.
class ProfilePhotoUpdated extends ProfileState {
  final ProfileEntity profile;
  final bool removed;

  const ProfilePhotoUpdated(this.profile, {this.removed = false});

  @override
  List<Object?> get props => [profile, removed];
}

/// The photo change failed; the rest of the profile is unaffected, so the
/// page keeps showing [profile] and only surfaces [message].
class ProfilePhotoFailed extends ProfileState {
  final ProfileEntity profile;
  final String message;

  const ProfilePhotoFailed(this.profile, this.message);

  @override
  List<Object?> get props => [profile, message];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
