part of 'widgets_preview_page.dart';

extension ComprehensivePreview on _WidgetsPreviewPageState {
  Widget _buildComprehensivePreview({bool showNutrition = true}) {
    final v = context.vColors;
    final stepsProgress = _stepsGoal > 0 ? (_steps / _stepsGoal).clamp(0.0, 1.0) : 0.0;
    final caloriesProgress = _caloriesGoal > 0 ? (_calories / _caloriesGoal).clamp(0.0, 1.0) : 0.0;
    final proteinProgress = 130 > 0 ? (_proteinG / 130).clamp(0.0, 1.0) : 0.0; // Assume 130g goal
    final carbsProgress = 200 > 0 ? (_carbsG / 200).clamp(0.0, 1.0) : 0.0; // Assume 200g goal
    final fatProgress = 60 > 0 ? (_fatG / 60).clamp(0.0, 1.0) : 0.0; // Assume 60g goal

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: v.glassBorder!),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14.0,
          vertical: AppDimens.space12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Today\'s Activity & Nutrition',
                  style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _buildStaticRefreshIcon(),
              ],
            ),
            const SizedBox(height: AppDimens.space10),
            
            // Steps & Calories main cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.space8),
                    decoration: BoxDecoration(
                      color: v.glassFill,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      border: Border.all(color: v.glassBorder!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset('assets/icons/steps.svg', width: 14, height: 14, colorFilter: ColorFilter.mode(AppColors.success, BlendMode.srcIn)),
                            const SizedBox(width: AppDimens.space4),
                            Text(
                              'Steps',
                              style: context.text.labelSmall?.copyWith(
                                color: v.grayText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.space4),
                        Text(
                          NumberFormat('#,###').format(_steps),
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/ ${NumberFormat('#,###').format(_stepsGoal)}',
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: v.grayText,
                          ),
                        ),
                        const SizedBox(height: AppDimens.space6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                          child: LinearProgressIndicator(
                            value: stepsProgress,
                            minHeight: AppDimens.space4,
                            backgroundColor: v.track,
                            valueColor: const AlwaysStoppedAnimation(AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.space6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.space8),
                    decoration: BoxDecoration(
                      color: v.glassFill,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      border: Border.all(color: v.glassBorder!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset('assets/icons/streak_3.svg', width: 14, height: 14, colorFilter: ColorFilter.mode(AppColors.warning, BlendMode.srcIn)),
                            const SizedBox(width: AppDimens.space4),
                            Text(
                              'Calories',
                              style: context.text.labelSmall?.copyWith(
                                color: v.grayText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.space4),
                        Text(
                          NumberFormat('#,###').format(_calories),
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/ ${NumberFormat('#,###').format(_caloriesGoal)}',
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: v.grayText,
                          ),
                        ),
                        const SizedBox(height: AppDimens.space6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                          child: LinearProgressIndicator(
                            value: caloriesProgress,
                            minHeight: AppDimens.space4,
                            backgroundColor: v.track,
                            valueColor: const AlwaysStoppedAnimation(AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            if (showNutrition) ...[
              const SizedBox(height: AppDimens.space8),
              // Macros (Protein, Carbs, Fat)
              Container(
                padding: const EdgeInsets.all(AppDimens.space10),
                decoration: BoxDecoration(
                  color: v.glassFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: v.glassBorder!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition Breakdown',
                      style: context.text.labelSmall?.copyWith(
                        color: v.grayText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space8),
                    _buildMacroBarPreview('Protein', '${_proteinG}g', proteinProgress, AppColors.streak),
                    const SizedBox(height: AppDimens.space6),
                    _buildMacroBarPreview('Carbs', '${_carbsG}g', carbsProgress, AppColors.warning),
                    const SizedBox(height: AppDimens.space6),
                    _buildMacroBarPreview('Fat', '${_fatG}g', fatProgress, AppColors.error),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBarPreview(String name, String grams, double progress, Color color) {
    final v = context.vColors;
    return Row(
      children: [
        SizedBox(
          width: 45,
          child: Text(
            name,
            style: context.text.labelSmall?.copyWith(
              color: v.grayText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: AppDimens.space4,
              backgroundColor: v.track,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.space6),
        SizedBox(
          width: 35,
          child: Text(
            grams,
            textAlign: TextAlign.end,
            style: context.text.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
