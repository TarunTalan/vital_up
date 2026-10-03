import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/mood_widgets.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

part 'comprehensive_preview.dart';
part 'mood_preview.dart';
part 'hydration_preview.dart';
part 'shortcuts_preview.dart';
part 'preview_helpers.dart';

class WidgetsPreviewPage extends StatefulWidget {
  const WidgetsPreviewPage({super.key});

  @override
  State<WidgetsPreviewPage> createState() => _WidgetsPreviewPageState();
}

class _WidgetsPreviewPageState extends State<WidgetsPreviewPage> {
  final int _waterMl = 1750;
  final int _waterGoalMl = 2500;
  final int _steps = 7420;
  final int _stepsGoal = 10000;
  final int _calories = 1640;
  final int _caloriesGoal = 2000;
  final int _proteinG = 110;
  final int _carbsG = 185;
  final int _fatG = 52;
  final int _streak = 5;

  Widget _buildStaticRefreshIcon() {
    final v = context.vColors;
    return Padding(
      padding: const EdgeInsets.all(AppDimens.space2),
      child: Icon(
        Icons.refresh_rounded,
        size: AppDimens.iconSm,
        color: v.grayText,
      ),
    );
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
      scrollable: true,
      padBody: false,
      body: Padding(
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
                    size: '4 × 3',
                    androidProvider: providerMultiFeature,
                    preview: _buildComprehensivePreview(),
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

                  // Widget 6: Hydration Tracker
                  _buildPreviewCard(
                    title: 'Hydration Tracker',
                    size: '3 × 2',
                    androidProvider: providerHydration,
                    preview: _buildHydrationPreview(),
                  ),


                  const SizedBox(height: AppDimens.sectionGap),

                  // Widget 8: Quick Shortcuts
                  _buildPreviewCard(
                    title: 'Quick Shortcuts',
                    size: '4 × 1',
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
                _buildStudioPill('assets/icons/size.svg', '3 Sizes', AppColors.primary),
                const SizedBox(width: AppDimens.space6),
                _buildStudioPill('assets/icons/theme.svg', '5 Themes', AppColors.blobPurple),
                const SizedBox(width: AppDimens.space6),
                _buildStudioPill('assets/icons/flash.svg', '6 Metrics', AppColors.success),
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

  Widget _buildStudioPill(String iconAsset, String label, Color color) {
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

  /// PREVIEW 2: Sleep & Recovery Tracker (Deep Link to Sleep Trends)


  /// PREVIEW 3: Food Log & Nutrition (Deep Link to Food Scanner / Meals)


  /// PREVIEW 4: Mood & Mindfulness (Deep Link to Stress/Mood Trends)


  /// PREVIEW 5: Stats & Daily Progress (Deep Link to Leaderboard & XP)




  /// PREVIEW 6: Hydration Tracker (Deep Link to Water Trends)

  /// PREVIEW 7: Activity & Steps (Deep Link to Activity Tracking)

  /// PREVIEW 8: Quick Shortcuts (Deep Links to Scan, Workout, Vita, Water)




}
