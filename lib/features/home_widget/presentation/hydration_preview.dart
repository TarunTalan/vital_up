part of 'widgets_preview_page.dart';

extension HydrationPreview on _WidgetsPreviewPageState {
  Widget _buildHydrationPreview() {
    final v = context.vColors;
    final waterProgress = _waterGoalMl > 0 ? (_waterMl / _waterGoalMl).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.water.withValues(alpha: 0.3)),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14.0,
          vertical: AppDimens.space12,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: AppDimens.iconBadgeLarge,
                      height: AppDimens.iconBadgeLarge,
                      child: CircularProgressIndicator(
                        value: waterProgress,
                        strokeWidth: AppDimens.borderThick * 2,
                        backgroundColor: v.track,
                        valueColor: const AlwaysStoppedAnimation(AppColors.water),
                      ),
                    ),
                    SvgPicture.asset(
                      'assets/icons/drop.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(AppColors.water, BlendMode.srcIn),
                    ),
                  ],
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Hydration',
                        style: context.text.labelSmall?.copyWith(
                          color: AppColors.water,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${NumberFormat('#,###').format(_waterMl)} ml',
                        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Goal: ${NumberFormat('#,###').format(_waterGoalMl)} ml (${(waterProgress * 100).toInt()}%)',
                        style: context.text.labelSmall?.copyWith(color: v.grayText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                _buildStaticRefreshIcon(),
              ],
            ),
            const SizedBox(height: AppDimens.space10),
            // Multiple Quick Water Logging Options
            Row(
              children: [
                _buildQuickWaterChip('+100 ml'),
                const SizedBox(width: AppDimens.space6),
                _buildQuickWaterChip('+250 ml'),
                const SizedBox(width: AppDimens.space6),
                _buildQuickWaterChip('+500 ml'),
                const SizedBox(width: AppDimens.space6),
                _buildQuickWaterChip('+1,000 ml'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickWaterChip(String label) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.space6,
          ),
          decoration: BoxDecoration(
            color: AppColors.water.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: AppColors.water.withValues(alpha: 0.3),
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: AppColors.water,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
