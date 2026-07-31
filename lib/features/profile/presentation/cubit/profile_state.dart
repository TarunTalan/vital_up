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

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
