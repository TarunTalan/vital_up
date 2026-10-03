import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

class WidgetsPreviewPage extends StatefulWidget {
  const WidgetsPreviewPage({super.key});

  @override
  State<WidgetsPreviewPage> createState() => _WidgetsPreviewPageState();
}

class _WidgetsPreviewPageState extends State<WidgetsPreviewPage> {
  bool _loading = true;
  int _waterMl = 0;
  int _waterGoalMl = 2500;
  int _steps = 0;
  int _stepsGoal = 10000;
  int _calories = 0;
  int _caloriesGoal = 2000;
  int _proteinG = 0;
  int _carbsG = 0;
  int _fatG = 0;
  int _sleepMinutes = 0;
  int _sleepGoalMinutes = 480;
  int _streak = 0;
  int _pointsToday = 0;

  @override
  void initState() {
    super.initState();
    _loadLiveMetrics();
  }

  Future<void> _loadLiveMetrics() async {
    final client = sl<SupabaseClient>();
    final userId = client.auth.currentUser?.id;
    final signedIn = userId != null && userId.isNotEmpty;

    int water = 0;
    int waterGoal = 2500;
    int steps = 0;
    int stepsGoal = 10000;
    int calories = 0;
    int caloriesGoal = 2000;
    int protein = 0;
    int carbs = 0;
    int fat = 0;
    int sleepMin = 0;
    int sleepGoalMin = 480;
    int streak = 0;
    int points = 0;

    if (signedIn) {
      try {
        final waterService = sl<WaterIntakeService>();
        final logs = await waterService.getTodayLogs(userId);
        water = logs.fold<int>(0, (sum, l) => sum + l.amountMl);
        waterGoal = waterService.getDailyGoal();
      } catch (_) {}

      try {
        final game = sl<GamificationRepository>();
        final (stats, pts) = await (
          game.getStats(),
          game.getPointsForDay(DateTime.now()),
        ).wait;
        streak = stats.streak;
        points = pts.values.fold<int>(0, (sum, p) => sum + p);
      } catch (_) {}

      try {
        final goalsRepo = sl<ActivityGoalsRepository>();
        final snapshot = await goalsRepo.getProgress(TrendRange.week);
        final stepGoal = snapshot.goals
            .where((g) => g.goal.metric == GoalMetric.steps)
            .firstOrNull;
        if (stepGoal != null) {
          steps = stepGoal.current.toInt();
          stepsGoal = stepGoal.goal.target.toInt();
        }
      } catch (_) {}

      try {
        final mealLogs = sl<GetMealLogHistory>();
        final result = await mealLogs(DateTime.now());
        result.fold((_) {}, (meals) {
          for (final m in meals) {
            calories += m.totalCalories.toInt();
            for (final n in m.nutrition) {
              protein += n.proteinG.toInt();
              carbs += n.carbsG.toInt();
              fat += n.fatG.toInt();
            }
          }
        });
      } catch (_) {}

      try {
        final sleepService = sl<SleepService>();
        sleepGoalMin = sleepService.getGoalMinutes();
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day - 1, 18);
        final end = DateTime(now.year, now.month, now.day, 23, 59);
        final sessions = await sleepService.getSleepBetween(start, end);
        if (sessions.isNotEmpty) {
          sleepMin = sessions.first.duration.inMinutes;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _waterMl = water > 0 ? water : 1750;
        _waterGoalMl = waterGoal;
        _steps = steps > 0 ? steps : 7420;
        _stepsGoal = stepsGoal;
        _calories = calories > 0 ? calories : 1640;
        _caloriesGoal = caloriesGoal;
        _proteinG = protein > 0 ? protein : 110;
        _carbsG = carbs > 0 ? carbs : 185;
        _fatG = fat > 0 ? fat : 52;
        _sleepMinutes = sleepMin > 0 ? sleepMin : 465; // 7h 45m
        _sleepGoalMinutes = sleepGoalMin;
        _streak = streak > 0 ? streak : 5;
        _pointsToday = points > 0 ? points : 120;
        _loading = false;
      });
    }
  }

  Future<void> _addHomeWidget(String providerName) async {
    HapticFeedback.lightImpact();
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: providerName,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Widget pin prompt opened');
      }
    } catch (_) {
      if (mounted) _showManualAddDialog();
    }
  }

  void _showManualAddDialog() {
    showSmoothDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
        ),
        backgroundColor: context.colors.surface,
        title: Row(
          children: [
            AppIconBadge(
              icon: Icon(Icons.widgets_rounded, color: context.colors.primary),
              color: context.colors.primary,
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Text(
                'Add to Home Screen',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To place a widget on your Android device:',
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.space12),
            _buildDialogStep('1', 'Go to your phone’s Home Screen.'),
            const SizedBox(height: AppDimens.space8),
            _buildDialogStep('2', 'Touch and hold any empty space.'),
            const SizedBox(height: AppDimens.space8),
            _buildDialogStep('3', 'Tap Widgets and search for VitalUp.'),
            const SizedBox(height: AppDimens.space8),
            _buildDialogStep('4', 'Drag and drop the widget onto your screen.'),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppDimens.space16,
          0,
          AppDimens.space16,
          AppDimens.space16,
        ),
        actions: [
          AppPrimaryButton(
            label: 'Got it',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppDimens.space20,
          height: AppDimens.space20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.vColors.primaryFill,
            shape: BoxShape.circle,
            border: Border.all(color: context.vColors.primaryBorder!),
          ),
          child: Text(
            number,
            style: context.text.labelSmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(
        title: 'Widgets',
        subtitle: 'Showcase & Studio',
      ),
      scrollable: !_loading,
      padBody: false,
      body: _loading
          ? const Center(
              child: VitalUpLoader(),
            )
          : Padding(
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.sectionGap,
                context.gutter,
                AppDimens.sectionGap + context.safePadding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOP CARD: Custom Widget Studio Builder
                  _buildCustomStudioCard(),

                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 1: Multi-Feature Vitals
                  _buildPreviewCard(
                    title: 'Multi-Feature Vitals',
                    size: '3 × 2',
                    androidProvider: providerMultiFeature,
                    preview: _buildComprehensivePreview(),
                  ),

                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 2: Sleep & Recovery Tracker
                  _buildPreviewCard(
                    title: 'Sleep & Recovery',
                    size: '3 × 2',
                    androidProvider: providerSleep,
                    preview: _buildSleepPreview(),
                  ),

                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 3: Food Log & Nutrition
                  _buildPreviewCard(
                    title: 'Food Log & Macros',
                    size: '3 × 2',
                    androidProvider: providerFoodLog,
                    preview: _buildFoodLogPreview(),
                  ),

                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 4: Mood & Mindfulness
                  _buildPreviewCard(
                    title: 'Mood & Mindfulness',
                    size: '3 × 2',
                    androidProvider: providerMood,
                    preview: _buildMoodLogPreview(),
                  ),

                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 5: Health Stats & Progress
                  _buildPreviewCard(
                    title: 'Stats & Daily Progress',
                    size: '3 × 2',
                    androidProvider: providerStats,
                    preview: _buildStatsProgressPreview(),
                  ),

                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 6: Hydration Tracker
                  _buildPreviewCard(
                    title: 'Hydration Tracker',
                    size: '3 × 2',
                    androidProvider: providerHydration,
                    preview: _buildHydrationPreview(),
                  ),

                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 7: Activity & Steps
                  _buildPreviewCard(
                    title: 'Activity & Steps',
                    size: '3 × 2',
                    androidProvider: providerActivity,
                    preview: _buildActivityPreview(),
                  ),

                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 8: Quick Shortcuts
                  _buildPreviewCard(
                    title: 'Quick Shortcuts',
                    size: '2 × 1',
                    androidProvider: providerShortcuts,
                    preview: _buildShortcutsPreview(),
                  ),
                ],
              ),
            ),
    );
  }

  /// TOP CARD: Custom Widget Studio Showcase
  Widget _buildCustomStudioCard() {
    final v = context.vColors;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPadding,
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                color: AppColors.primary,
                size: AppDimens.iconBadge,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Widget Studio',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      'Design your own widget layout & colors',
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space8,
                  vertical: AppDimens.space4,
                ),
                decoration: BoxDecoration(
                  color: v.primaryFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: v.primaryBorder!),
                ),
                child: Text(
                  'BUILDER',
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.space16),

          // Mini interactive teaser container
          Container(
            padding: const EdgeInsets.all(AppDimens.space12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: v.glassBorder!),
            ),
            child: Row(
              children: [
                _buildStudioPill('📐 3 Sizes', AppColors.primary),
                const SizedBox(width: AppDimens.space6),
                _buildStudioPill('🎨 5 Themes', AppColors.blobPurple),
                const SizedBox(width: AppDimens.space6),
                _buildStudioPill('⚡ 6 Metrics', AppColors.success),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.space16),

          AppPrimaryButton(
            label: 'Customize Your Widget',
            leadingIcon: const Icon(Icons.auto_awesome_rounded, size: AppDimens.iconMd),
            onTap: () => context.pushNamed('custom-widget-builder'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioPill(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space4,
          vertical: AppDimens.space6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard({
    required String title,
    required String size,
    required String androidProvider,
    required Widget preview,
  }) {
    final v = context.vColors;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Size Chip
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space8,
                  vertical: AppDimens.space4,
                ),
                decoration: BoxDecoration(
                  color: v.primaryFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: v.primaryBorder!),
                ),
                child: Text(
                  size,
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.space16),

          // Widget Preview Canvas
          preview,

          const SizedBox(height: AppDimens.space16),

          // Global AppPrimaryButton
          AppPrimaryButton(
            label: 'Add to Home Screen',
            leadingIcon: const Icon(Icons.add_rounded, size: AppDimens.iconMd),
            onTap: () => _addHomeWidget(androidProvider),
          ),
        ],
      ),
    );
  }

  /// PREVIEW 1: Multi-Feature Vitals
  Widget _buildComprehensivePreview() {
    final v = context.vColors;
    final waterProgress = _waterGoalMl > 0 ? (_waterMl / _waterGoalMl).clamp(0.0, 1.0) : 0.0;
    final stepsProgress = _stepsGoal > 0 ? (_steps / _stepsGoal).clamp(0.0, 1.0) : 0.0;
    final caloriesProgress = _caloriesGoal > 0 ? (_calories / _caloriesGoal).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.goNamed('dashboard');
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: v.glassBorder!),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Streak & Points (Deep Links to Leaderboard/XP)
            Row(
              children: [
                if (_streak > 0) ...[
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.pushNamed('leaderboard');
                    },
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space8,
                        vertical: AppDimens.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.streak.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥 ', style: TextStyle(fontSize: 12)),
                          Text(
                            '$_streak-Day Streak',
                            style: context.text.labelSmall?.copyWith(
                              color: AppColors.streak,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: AppDimens.space8,
                    height: AppDimens.space8,
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
                if (_pointsToday > 0)
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.pushNamed('points-history');
                      },
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      child: Text(
                        '+$_pointsToday pts',
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: v.grayText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: AppDimens.space6),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _loadLiveMetrics();
                  },
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.space2),
                    child: Icon(Icons.refresh_rounded, size: AppDimens.iconSm, color: v.grayText),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimens.space10),

            // Water Section (Deep Link to Water Trends)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                context.pushNamed('water-trends');
              },
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space10,
                  vertical: AppDimens.space8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.water.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: AppColors.water.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '💧 Water',
                                style: context.text.labelSmall?.copyWith(
                                  color: AppColors.water,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: AppDimens.space4),
                              Expanded(
                                child: Text(
                                  '${NumberFormat('#,###').format(_waterMl)} / ${NumberFormat('#,###').format(_waterGoalMl)} ml',
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.space4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                            child: LinearProgressIndicator(
                              value: waterProgress,
                              minHeight: AppDimens.space4,
                              backgroundColor: v.track,
                              valueColor: const AlwaysStoppedAnimation(AppColors.water),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space8,
                        vertical: AppDimens.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.water,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Text(
                        '+250 ml',
                        style: context.text.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppDimens.space8),

            // Steps & Calories Row (Deep Links to Activity & Food Scan)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.pushNamed('activity-tracking');
                    },
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
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
                          Text(
                            '👟 Steps',
                            style: context.text.labelSmall?.copyWith(
                              color: v.grayText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimens.space2),
                          Text(
                            '${NumberFormat('#,###').format(_steps)} / ${NumberFormat('#,###').format(_stepsGoal)}',
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimens.space4),
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
                ),
                const SizedBox(width: AppDimens.space6),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.pushNamed('food-scan');
                    },
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
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
                          Text(
                            '🔥 Calories',
                            style: context.text.labelSmall?.copyWith(
                              color: v.grayText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimens.space2),
                          Text(
                            '${NumberFormat('#,###').format(_calories)} / ${NumberFormat('#,###').format(_caloriesGoal)}',
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimens.space4),
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
                ),
              ],
            ),

            const SizedBox(height: AppDimens.space8),

            // Shortcuts
            Row(
              children: [
                _buildMiniChip('📷 Scan', () => context.pushNamed('food-scan')),
                const SizedBox(width: AppDimens.space4),
                _buildMiniChip('🏃 Track', () => context.pushNamed('activity-tracking')),
                const SizedBox(width: AppDimens.space4),
                _buildMiniChip('🤖 Vita', () => context.pushNamed('vita-chat')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// PREVIEW 2: Sleep & Recovery Tracker (Deep Link to Sleep Trends)
  Widget _buildSleepPreview() {
    final v = context.vColors;
    final hours = _sleepMinutes ~/ 60;
    final mins = _sleepMinutes % 60;
    final sleepProgress = _sleepGoalMinutes > 0 ? (_sleepMinutes / _sleepGoalMinutes).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.pushNamed('sleep-trends');
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.sleep.withValues(alpha: 0.3)),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.nightlight_round, color: AppColors.sleep, size: AppDimens.iconMd),
                const SizedBox(width: AppDimens.space6),
                Expanded(
                  child: Text(
                    'Sleep & Recovery',
                    style: context.text.labelMedium?.copyWith(
                      color: AppColors.sleep,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space6,
                    vertical: AppDimens.space2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sleep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    '88% Optimal',
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.sleep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${hours}h ${mins}m',
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.space2),
                      Text(
                        'Goal: ${_sleepGoalMinutes ~/ 60}h 00m • 11:15 PM → 7:00 AM',
                        style: context.text.labelSmall?.copyWith(color: v.grayText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space8,
                    vertical: AppDimens.space6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sleep,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    'Log Sleep',
                    style: context.text.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              child: LinearProgressIndicator(
                value: sleepProgress,
                minHeight: AppDimens.space4,
                backgroundColor: v.track,
                valueColor: const AlwaysStoppedAnimation(AppColors.sleep),
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            Row(
              children: [
                _buildSleepStage('Deep 1h 45m', AppColors.sleep),
                const SizedBox(width: AppDimens.space4),
                _buildSleepStage('REM 2h 10m', AppColors.blobPurple),
                const SizedBox(width: AppDimens.space4),
                _buildSleepStage('Light 3h 50m', AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepStage(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space2,
          vertical: AppDimens.space2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimens.radiusXs),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  /// PREVIEW 3: Food Log & Nutrition (Deep Link to Food Scanner / Meals)
  Widget _buildFoodLogPreview() {
    final v = context.vColors;
    final calProgress = _caloriesGoal > 0 ? (_calories / _caloriesGoal).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.pushNamed('food-scan');
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.protein.withValues(alpha: 0.3)),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_rounded, color: AppColors.protein, size: AppDimens.iconMd),
                const SizedBox(width: AppDimens.space6),
                Expanded(
                  child: Text(
                    'Food Log & Nutrition',
                    style: context.text.labelMedium?.copyWith(
                      color: AppColors.protein,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                Flexible(
                  child: Text(
                    '${NumberFormat('#,###').format(_calories)} / ${NumberFormat('#,###').format(_caloriesGoal)} kcal',
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              child: LinearProgressIndicator(
                value: calProgress,
                minHeight: AppDimens.space4,
                backgroundColor: v.track,
                valueColor: const AlwaysStoppedAnimation(AppColors.protein),
              ),
            ),
            const SizedBox(height: AppDimens.space10),
            Row(
              children: [
                _buildMacroBar('Protein', '${_proteinG}g', 0.75, AppColors.protein),
                const SizedBox(width: AppDimens.space6),
                _buildMacroBar('Carbs', '${_carbsG}g', 0.65, AppColors.carbs),
                const SizedBox(width: AppDimens.space6),
                _buildMacroBar('Fats', '${_fatG}g', 0.50, AppColors.fat),
              ],
            ),
            const SizedBox(height: AppDimens.space10),
            Row(
              children: [
                _buildMiniChip('🍳 Breakfast', () => context.pushNamed('food-scan')),
                const SizedBox(width: AppDimens.space4),
                _buildMiniChip('🥗 Lunch', () => context.pushNamed('food-scan')),
                const SizedBox(width: AppDimens.space4),
                _buildMiniChip('🍲 Dinner', () => context.pushNamed('food-scan')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String name, String grams, double progress, Color color) {
    final v = context.vColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppDimens.space6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  grams,
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space4),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: AppDimens.space2 + 1,
                backgroundColor: v.track,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PREVIEW 4: Mood & Mindfulness (Deep Link to Stress/Mood Trends)
  Widget _buildMoodLogPreview() {
    final v = context.vColors;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.pushNamed('stress-trends');
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.stressLevels[0].withValues(alpha: 0.35)),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.self_improvement_rounded,
                  color: AppColors.stressLevels[0],
                  size: AppDimens.iconMd,
                ),
                const SizedBox(width: AppDimens.space6),
                Expanded(
                  child: Text(
                    'Mindfulness & Mood',
                    style: context.text.labelMedium?.copyWith(
                      color: AppColors.stressLevels[0],
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                if (_streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space6,
                      vertical: AppDimens.space2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.streak.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      '🔥 $_streak days',
                      style: context.text.labelSmall?.copyWith(
                        color: AppColors.streak,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '😊 Calm & Centered',
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.space2),
                      Text(
                        'Checked in today at 9:30 AM',
                        style: context.text.labelSmall?.copyWith(color: v.grayText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space10,
                    vertical: AppDimens.space6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stressLevels[0],
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    'Check In',
                    style: context.text.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space10),
            // 5 face mood selector preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMoodEmoji('😄', AppColors.stressLevels[0], isSelected: true),
                _buildMoodEmoji('🙂', AppColors.stressLevels[1], isSelected: false),
                _buildMoodEmoji('😐', AppColors.stressLevels[2], isSelected: false),
                _buildMoodEmoji('🙁', AppColors.stressLevels[3], isSelected: false),
                _buildMoodEmoji('😫', AppColors.stressLevels[4], isSelected: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodEmoji(String emoji, Color color, {required bool isSelected}) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.pushNamed('stress-trends');
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  /// PREVIEW 5: Stats & Daily Progress (Deep Link to Leaderboard & XP)
  Widget _buildStatsProgressPreview() {
    final v = context.vColors;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.pushNamed('leaderboard');
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.rankGold, size: AppDimens.iconMd),
                const SizedBox(width: AppDimens.space6),
                Expanded(
                  child: Text(
                    'Daily Vital Score & XP',
                    style: context.text.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space6,
                    vertical: AppDimens.space2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.rankGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    '🏆 Rank #3',
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.rankGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space10),
            Row(
              children: [
                // Vital Score Circle
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.primary, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '92',
                        style: context.text.titleSmall?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'SCORE',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+$_pointsToday XP Today',
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.space2),
                      Text(
                        'Streak: $_streak days • 3 / 4 Goals done',
                        style: context.text.labelSmall?.copyWith(color: v.grayText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space10),
            // Daily goals checklist strip
            Row(
              children: [
                _buildGoalChip('💧 Water', true, () => context.pushNamed('water-trends')),
                const SizedBox(width: AppDimens.space4),
                _buildGoalChip('👟 Steps', true, () => context.pushNamed('activity-tracking')),
                const SizedBox(width: AppDimens.space4),
                _buildGoalChip('🥗 Meals', true, () => context.pushNamed('food-scan')),
                const SizedBox(width: AppDimens.space4),
                _buildGoalChip('🌙 Sleep', false, () => context.pushNamed('sleep-trends')),
              ],
            ),
          ],
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

  /// PREVIEW 6: Hydration Tracker (Deep Link to Water Trends)
  Widget _buildHydrationPreview() {
    final v = context.vColors;
    final waterProgress = _waterGoalMl > 0 ? (_waterMl / _waterGoalMl).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.pushNamed('water-trends');
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.water.withValues(alpha: 0.3)),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Row(
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
                const Icon(Icons.water_drop_rounded, color: AppColors.water, size: AppDimens.iconLg),
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
                    style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space8,
                vertical: AppDimens.space6,
              ),
              decoration: BoxDecoration(
                color: AppColors.water,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Text(
                '+250 ml',
                style: context.text.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PREVIEW 7: Activity & Steps (Deep Link to Activity Tracking)
  Widget _buildActivityPreview() {
    final v = context.vColors;
    final stepsProgress = _stepsGoal > 0 ? (_steps / _stepsGoal).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.pushNamed('activity-tracking');
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          boxShadow: AppShadows.shadowY,
        ),
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_run_rounded, color: AppColors.success, size: AppDimens.iconMd),
                const SizedBox(width: AppDimens.space6),
                Expanded(
                  child: Text(
                    'Steps & Activity',
                    style: context.text.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                if (_streak > 0)
                  Text(
                    '🔥 $_streak days',
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.streak,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        NumberFormat('#,###').format(_steps),
                        style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Goal: ${NumberFormat('#,###').format(_stepsGoal)} steps',
                        style: context.text.labelSmall?.copyWith(color: v.grayText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space10,
                    vertical: AppDimens.space6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    'Start',
                    style: context.text.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
    );
  }

  /// PREVIEW 8: Quick Shortcuts (Deep Links to Scan, Workout, Vita, Water)
  Widget _buildShortcutsPreview() {
    final v = context.vColors;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder!),
        boxShadow: AppShadows.shadowY,
      ),
      padding: const EdgeInsets.all(AppDimens.space8),
      child: Row(
        children: [
          _buildShortcutIcon(
            Icons.qr_code_scanner_rounded,
            AppColors.success,
            'Scan',
            () => context.pushNamed('food-scan'),
          ),
          const SizedBox(width: AppDimens.space6),
          _buildShortcutIcon(
            Icons.directions_run_rounded,
            AppColors.warning,
            'Workout',
            () => context.pushNamed('activity-tracking'),
          ),
          const SizedBox(width: AppDimens.space6),
          _buildShortcutIcon(
            Icons.auto_awesome_rounded,
            AppColors.blobPurple,
            'Vita AI',
            () => context.pushNamed('vita-chat'),
          ),
          const SizedBox(width: AppDimens.space6),
          _buildShortcutIcon(
            Icons.water_drop_rounded,
            AppColors.water,
            '+250ml',
            () => context.pushNamed('water-trends'),
          ),
        ],
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

  Widget _buildShortcutIcon(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
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
              Icon(icon, color: color, size: AppDimens.iconMd),
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
