part of 'widgets_preview_page.dart';

extension ShortcutsPreview on _WidgetsPreviewPageState {
  Widget _buildShortcutsPreview() {
    final v = context.vColors;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder!),
        boxShadow: AppShadows.shadowY,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space8,
      ),
      child: Row(
        children: [
          _buildShortcutItem(
            icon: SvgPicture.asset(
              'assets/icons/scanner.svg',
              width: AppDimens.iconMd,
              height: AppDimens.iconMd,
              colorFilter: const ColorFilter.mode(AppColors.success, BlendMode.srcIn),
            ),
            color: AppColors.success,
            label: 'Scan',
            onTap: () {
              context.pushNamed('food-scan');
            },
          ),
          const SizedBox(width: AppDimens.space6),
          _buildShortcutItem(
            icon: const Icon(Icons.directions_run_rounded, color: AppColors.warning, size: AppDimens.iconMd),
            color: AppColors.warning,
            label: 'Workout',
            onTap: () {
              context.pushNamed('activity-tracking');
            },
          ),
          const SizedBox(width: AppDimens.space6),
          _buildShortcutItem(
            icon: SvgPicture.asset(
              'assets/icons/vita.svg',
              width: AppDimens.iconMd,
              height: AppDimens.iconMd,
              colorFilter: const ColorFilter.mode(AppColors.blobPurple, BlendMode.srcIn),
            ),
            color: AppColors.blobPurple,
            label: 'Vita AI',
            onTap: () {
              context.pushNamed('vita-chat');
            },
          ),
          const SizedBox(width: AppDimens.space6),
          _buildShortcutItem(
            icon: SvgPicture.asset(
              'assets/icons/drop.svg',
              width: AppDimens.iconMd,
              height: AppDimens.iconMd,
              colorFilter: const ColorFilter.mode(AppColors.water, BlendMode.srcIn),
            ),
            color: AppColors.water,
            label: '+250ml',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutItem({
    required Widget icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space2,
            vertical: AppDimens.space6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: AppDimens.space2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
