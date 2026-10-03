part of 'widgets_preview_page.dart';

extension PreviewHelpers on _WidgetsPreviewPageState {
  Widget _buildGoalChipWithIcon(String label, String iconAsset, bool completed, VoidCallback onTap) {
    final color = completed
        ? AppColors.success
        : (context.vColors.grayText ?? AppColors.greyText);
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: completed ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(iconAsset, width: 12, height: 12, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 10,
                    color: color,
                    fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalChip(String label, bool completed, VoidCallback onTap) {
    final color = completed
        ? AppColors.success
        : (context.vColors.grayText ?? AppColors.greyText);
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
            vertical: AppDimens.space4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: completed ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppDimens.space2),
                Icon(
                  completed ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                  size: 10,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChipWithIcon(String label, String iconAsset, VoidCallback onTap) {
    final v = context.vColors;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: v.glassFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(iconAsset, width: 12, height: 12, colorFilter: ColorFilter.mode(v.grayText!, BlendMode.srcIn)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 10,
                    color: v.grayText,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label, VoidCallback onTap) {
    final v = context.vColors;
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
            vertical: AppDimens.space4,
          ),
          decoration: BoxDecoration(
            color: v.glassFill,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: context.text.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

}
