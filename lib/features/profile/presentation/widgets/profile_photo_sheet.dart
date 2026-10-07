import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/user_avatar.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';

enum _PhotoAction { camera, gallery, remove }

/// Take, choose or remove the profile photo through [cubit].
Future<void> showProfilePhotoOptions(
  BuildContext context,
  ProfileCubit cubit,
  ProfileEntity profile,
) async {
  if (cubit.state is ProfilePhotoUpdating) return;

  final choice = await showAppBottomSheet<_PhotoAction>(
    context: context,
    isScrollControlled: false,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.space16,
          0,
          AppDimens.space16,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListGroup(
              children: [
                AppListTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take photo',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_PhotoAction.camera),
                ),
                AppListTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_PhotoAction.gallery),
                ),
                if (profile.photoUrl != null)
                  AppListTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Remove photo',
                    destructive: true,
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_PhotoAction.remove),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;

  if (choice == _PhotoAction.remove) {
    final confirmed = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text('Your profile will show your initial instead.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.removePhoto();
    return;
  }

  try {
    final picked = await ImagePicker().pickImage(
      source: choice == _PhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return;
    await cubit.uploadPhoto(File(picked.path));
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      choice == _PhotoAction.camera
          ? 'Camera access is needed to take a photo. You can allow it in Settings.'
          : 'Photo access is needed to choose a picture. You can allow it in Settings.',
    );
  }
}

/// The large rounded-square profile avatar with a camera badge; shows a
/// spinner while a photo uploads.
class ProfileAvatar extends StatelessWidget {
  final ProfileEntity profile;
  final bool uploading;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    required this.profile,
    this.uploading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName.isNotEmpty
        ? profile.fullName
        : profile.username;
    final colors = context.colors;
    return Semantics(
      button: onTap != null,
      label: 'Change profile photo',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(
              username: name,
              url: profile.photoUrl,
              size: AppDimens.avatarLarge,
              borderRadius: AppDimens.radiusCard,
              initialStyle: context.text.headlineMedium,
            ),
            if (uploading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.vColors.glassFill,
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  ),
                  child: Center(
                    child: SizedBox.square(
                      dimension: AppDimens.iconXl,
                      child: CircularProgressIndicator(
                        strokeWidth: AppDimens.borderThick,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            if (onTap != null)
              Positioned(
                right: -AppDimens.space4,
                bottom: -AppDimens.space4,
                child: Container(
                  width: AppDimens.iconXl - AppDimens.space4,
                  height: AppDimens.iconXl - AppDimens.space4,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.surface,
                      width: AppDimens.borderThick,
                    ),
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: AppDimens.iconXs,
                    color: context.vColors.buttonText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
