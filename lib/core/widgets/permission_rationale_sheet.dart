import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';

enum PermissionType {
  location(
    title: 'Precise GPS Location',
    description:
        'VitalUp uses GPS to map your outdoor running, cycling, and walking routes, calculate accurate pace, and track split intervals.',
    icon: Icons.location_on_rounded,
    color: AppColors.primary,
  ),
  health(
    title: 'Health Connect Sync',
    description:
        'Allows VitalUp to securely read workouts, step counts, and sleep stages recorded from your smartwatch and fitness wearables.',
    icon: Icons.favorite_rounded,
    color: AppColors.error,
  ),
  camera(
    title: 'Camera & Food Scanner',
    description:
        'Required to scan food packaging barcodes and extract nutrition label facts offline using Google ML Kit.',
    icon: Icons.camera_alt_rounded,
    color: AppColors.teal,
  ),
  notifications(
    title: 'Smart Reminders',
    description:
        'Delivers morning sleep check-ins, hydration pace nudges throughout the day, and milestone celebrations.',
    icon: Icons.notifications_active_rounded,
    color: AppColors.warning,
  );

  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const PermissionType({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

Future<bool> showPermissionRationaleSheet(
  BuildContext context, {
  required PermissionType type,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusSheet),
      ),
    ),
    builder: (sheetContext) => _PermissionRationaleContent(type: type),
  );
  return result ?? false;
}

class _PermissionRationaleContent extends StatelessWidget {
  final PermissionType type;

  const _PermissionRationaleContent({required this.type});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.space20,
          context.gutter,
          AppDimens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon Badge
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: type.color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: type.color.withAlpha(70),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(type.icon, size: 36, color: type.color),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space16),

            // Title
            Text(
              type.title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimens.space8),

            // Description
            Text(
              type.description,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: v.grayText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppDimens.space16),

            // Privacy Assurance Pill
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space12,
                vertical: AppDimens.space8,
              ),
              decoration: BoxDecoration(
                color: v.glassFill,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(
                  color: v.glassBorder ?? AppColors.glassBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: AppDimens.iconSm,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppDimens.space8),
                  Expanded(
                    child: Text(
                      'Your data stays strictly private & encrypted on your device.',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurface.withAlpha(200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.space24),

            // Continue Button
            AppPrimaryButton(
              label: 'Allow & Continue',
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: AppDimens.space8),

            // Maybe Later Button
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Maybe Later',
                style: context.text.bodySmall?.copyWith(
                  color: v.grayText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
