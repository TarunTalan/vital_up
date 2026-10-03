part of 'widgets_preview_page.dart';

extension MoodPreview on _WidgetsPreviewPageState {
  Widget _buildMoodLogPreview() {
    final v = context.vColors;
    const moodIcons = [
      Icons.sentiment_very_satisfied_rounded,
      Icons.sentiment_satisfied_rounded,
      Icons.sentiment_neutral_rounded,
      Icons.sentiment_dissatisfied_rounded,
      Icons.sentiment_very_dissatisfied_rounded,
    ];
    const moodLabels = [
      'Very calm',
      'Calm',
      'Okay',
      'Stressed',
      'Very stressed',
    ];

    final titleColor = AppColors.stressLevels[1]; // Calm color for title

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: titleColor.withValues(alpha: 0.35)),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14.0,
          vertical: AppDimens.space12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title & Refresh Icon
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mindfulness & Mood',
                    style: context.text.labelMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStaticRefreshIcon(),
              ],
            ),
            const SizedBox(height: AppDimens.space6),

            // Streak Pill matching dashboard StressCheckInCard
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space8,
                  vertical: AppDimens.space4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.streak.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _streak > 0
                          ? Icons.local_fire_department_rounded
                          : Icons.local_fire_department_outlined,
                      size: 14,
                      color: AppColors.streak,
                    ),
                    const SizedBox(width: AppDimens.space4),
                    Text(
                      _streak > 0
                          ? '$_streak-day streak · check in to keep it'
                          : 'Check in today to start a streak',
                      style: context.text.labelSmall?.copyWith(
                        color: AppColors.streak,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space10),

            // 5 Face Mood Selector Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                final color = AppColors.stressLevels[index];
                final icon = moodIcons[index];
                return Expanded(
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 1 ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: index == 1 ? color : color.withValues(alpha: 0.3),
                          width: index == 1 ? 1.8 : 1.0,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 22,
                        semanticLabel: moodLabels[index],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppDimens.space10),

            // What's on your mind prompt
            Text(
              "What's on your mind? (optional)",
              style: context.text.bodySmall?.copyWith(
                color: v.grayText,
              ),
            ),
            const SizedBox(height: AppDimens.space6),

            // Horizontal Scrolling Tags Row using Dashboard Icons (tag.icon)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: StressTag.values.map((tag) {
                  final isTagSelected = tag == StressTag.work;
                  return Container(
                    margin: const EdgeInsets.only(right: AppDimens.space6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space8,
                      vertical: AppDimens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: isTagSelected ? titleColor.withValues(alpha: 0.15) : v.glassFill,
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      border: Border.all(
                        color: isTagSelected ? titleColor : v.glassBorder!,
                        width: isTagSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tag.icon,
                          size: 13,
                          color: isTagSelected ? titleColor : context.colors.onSurface,
                        ),
                        const SizedBox(width: AppDimens.space4),
                        Text(
                          isTagSelected ? '✓ ${tag.label}' : tag.label,
                          style: context.text.labelSmall?.copyWith(
                            color: isTagSelected ? titleColor : context.colors.onSurface,
                            fontWeight: isTagSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppDimens.space10),

            // Check In Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: titleColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Text(
                'Check In',
                style: context.text.labelMedium?.copyWith(
                  color: context.isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
