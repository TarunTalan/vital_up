import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';

const _androidProvider = 'com.tarun_siddhi.vital_up.VitalUpWidgetProvider';

enum WidgetSizeOption {
  compact('2 × 1', 'Compact Quick Bar', Icons.view_headline_rounded),
  medium('3 × 2', 'Balanced Daily View', Icons.dashboard_rounded),
  large('4 × 2', 'Full Dashboard', Icons.grid_view_rounded);

  final String sizeLabel;
  final String description;
  final IconData icon;
  const WidgetSizeOption(this.sizeLabel, this.description, this.icon);
}

enum WidgetColorTheme {
  vitalCyan('Vital Cyan', AppColors.primary),
  hydrationBlue('Aqua Wave', AppColors.water),
  emeraldEnergy('Emerald', AppColors.success),
  sunsetOrange('Sunset', AppColors.warning),
  vitaPurple('Vita Aura', AppColors.blobPurple);

  final String name;
  final Color primaryColor;
  const WidgetColorTheme(this.name, this.primaryColor);
}

class CustomWidgetBuilderPage extends StatefulWidget {
  const CustomWidgetBuilderPage({super.key});

  @override
  State<CustomWidgetBuilderPage> createState() => _CustomWidgetBuilderPageState();
}

class _CustomWidgetBuilderPageState extends State<CustomWidgetBuilderPage> {
  WidgetSizeOption _selectedSize = WidgetSizeOption.medium;
  WidgetColorTheme _selectedTheme = WidgetColorTheme.vitalCyan;

  bool _showWater = true;
  bool _showSteps = true;
  bool _showCalories = true;
  bool _showSleep = true;
  bool _showMood = true;
  final bool _showStreak = true;
  bool _showShortcuts = true;

  Future<void> _pinCustomWidget() async {
    HapticFeedback.mediumImpact();
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: _androidProvider,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Widget added to your home screen!');
      }
    } catch (_) {
      if (mounted) {
        showSuccessSnackBar(
          context,
          'Configuration saved! Long press your home screen to place the widget.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(
        title: 'Custom Widget',
        subtitle: 'Build your personalized widget',
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
            // Section 1: Live Interactive Preview
            AppCaption('LIVE PREVIEW (${_selectedSize.sizeLabel})'),
            const SizedBox(height: AppDimens.space8),
            _buildLivePreviewCard(),

            const SizedBox(height: AppDimens.sectionGap),

            // Section 2: Choose Widget Layout / Size
            AppCaption('1. SELECT WIDGET SIZE'),
            const SizedBox(height: AppDimens.space8),
            _buildSizeSelector(),

            const SizedBox(height: AppDimens.sectionGap),

            // Section 3: Accent Theme
            AppCaption('2. SELECT COLOR ACCENT'),
            const SizedBox(height: AppDimens.space8),
            _buildThemeSelector(),

            const SizedBox(height: AppDimens.sectionGap),

            // Section 4: Visible Metrics
            AppCaption('3. VISIBLE METRICS & MODULES'),
            const SizedBox(height: AppDimens.space8),
            _buildMetricsToggles(),

            const SizedBox(height: AppDimens.sectionGap),

            // Add / Pin Button
            AppPrimaryButton(
              label: 'Save & Add Widget',
              leadingIcon: const Icon(Icons.check_circle_rounded, size: AppDimens.iconMd),
              containerColor: _selectedTheme.primaryColor,
              contentColor: Colors.white,
              onTap: _pinCustomWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final v = context.vColors;
    final accent = _selectedTheme.primaryColor;

    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Widget Mockup Frame
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              boxShadow: AppShadows.shadowY,
            ),
            padding: const EdgeInsets.all(AppDimens.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header
                Row(
                  children: [
                    if (_showStreak) ...[
                      Container(
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
                              '5-Day Streak',
                              style: context.text.labelSmall?.copyWith(
                                color: AppColors.streak,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: AppDimens.space8,
                        height: AppDimens.space8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space6,
                        vertical: AppDimens.space2,
                      ),
                      decoration: BoxDecoration(
                        color: v.glassFill,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(color: v.glassBorder!),
                      ),
                      child: Text(
                        _selectedSize.sizeLabel,
                        style: context.text.labelSmall?.copyWith(
                          color: v.grayText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                if (_selectedSize != WidgetSizeOption.compact) ...[
                  const SizedBox(height: AppDimens.space10),

                  // Water Metric
                  if (_showWater) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space10,
                        vertical: AppDimens.space6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.water.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(color: AppColors.water.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '💧 1,750 / 2,500 ml',
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: AppColors.water,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.space6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.space6,
                              vertical: AppDimens.space2,
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
                    const SizedBox(height: AppDimens.space6),
                  ],

                  // Activity Metrics Row
                  if (_showSteps || _showCalories) ...[
                    Row(
                      children: [
                        if (_showSteps)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(AppDimens.space6),
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '7,840 / 10k',
                                    style: context.text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_showSteps && _showCalories)
                          const SizedBox(width: AppDimens.space6),
                        if (_showCalories)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(AppDimens.space6),
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '1,620 kcal',
                                    style: context.text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.space6),
                  ],

                  // Sleep & Mood Row (For Large or medium widgets)
                  if (_showSleep || _showMood) ...[
                    Row(
                      children: [
                        if (_showSleep)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(AppDimens.space6),
                              decoration: BoxDecoration(
                                color: AppColors.sleep.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                border: Border.all(color: AppColors.sleep.withValues(alpha: 0.2)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '🌙 7h 45m Sleep',
                                  style: context.text.labelSmall?.copyWith(
                                    color: AppColors.sleep,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_showSleep && _showMood)
                          const SizedBox(width: AppDimens.space6),
                        if (_showMood)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(AppDimens.space6),
                              decoration: BoxDecoration(
                                color: AppColors.stressLevels[0].withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                border: Border.all(color: AppColors.stressLevels[0].withValues(alpha: 0.25)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '😊 Calm & Good',
                                  style: context.text.labelSmall?.copyWith(
                                    color: AppColors.stressLevels[0],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.space6),
                  ],
                ],

                // Quick Shortcuts Row
                if (_showShortcuts) ...[
                  const SizedBox(height: AppDimens.space4),
                  Row(
                    children: [
                      _buildMiniShortcut('📷 Scan', accent),
                      const SizedBox(width: AppDimens.space4),
                      _buildMiniShortcut('🏃 Run', accent),
                      const SizedBox(width: AppDimens.space4),
                      _buildMiniShortcut('🤖 Vita', accent),
                      if (_selectedSize == WidgetSizeOption.large) ...[
                        const SizedBox(width: AppDimens.space4),
                        _buildMiniShortcut('💧 +250ml', AppColors.water),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniShortcut(String label, Color color) {
    final v = context.vColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space2,
          vertical: AppDimens.space4,
        ),
        decoration: BoxDecoration(
          color: v.glassFill,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(color: v.glassBorder!),
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
    );
  }

  Widget _buildSizeSelector() {
    return Column(
      children: WidgetSizeOption.values.map((size) {
        final isSelected = _selectedSize == size;
        final color = _selectedTheme.primaryColor;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.space8),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedSize = size);
            },
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            child: Container(
              padding: const EdgeInsets.all(AppDimens.space12),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : context.vColors.glassFill,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                border: Border.all(
                  color: isSelected ? color : context.vColors.glassBorder!,
                  width: isSelected ? AppDimens.borderThick : AppDimens.borderThin,
                ),
              ),
              child: Row(
                children: [
                  Icon(size.icon, color: isSelected ? color : context.vColors.grayText),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          size.sizeLabel,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? color : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          size.description,
                          style: context.text.bodySmall?.copyWith(
                            color: context.vColors.grayText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: color, size: AppDimens.iconMd),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildThemeSelector() {
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: WidgetColorTheme.values.map((theme) {
            final isSelected = _selectedTheme == theme;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.space6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTheme = theme);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? context.colors.onSurface : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.primaryColor.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: AppDimens.iconSm)
                          : null,
                    ),
                    const SizedBox(height: AppDimens.space4),
                    Text(
                      theme.name,
                      style: context.text.labelSmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? theme.primaryColor : context.vColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMetricsToggles() {
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        children: [
          _buildToggleRow(
            '💧 Hydration (Water Tracker)',
            'Quick-add logs & progress',
            _showWater,
            (val) => setState(() => _showWater = val),
          ),
          const Divider(height: AppDimens.space12),
          _buildToggleRow(
            '👟 Daily Steps',
            'Step counter & progress toward goal',
            _showSteps,
            (val) => setState(() => _showSteps = val),
          ),
          const Divider(height: AppDimens.space12),
          _buildToggleRow(
            '🔥 Calories & Nutrition',
            'Daily calorie intake breakdown',
            _showCalories,
            (val) => setState(() => _showCalories = val),
          ),
          const Divider(height: AppDimens.space12),
          _buildToggleRow(
            '🌙 Sleep Duration',
            'Last night rest & sleep goal',
            _showSleep,
            (val) => setState(() => _showSleep = val),
          ),
          const Divider(height: AppDimens.space12),
          _buildToggleRow(
            '😊 Mood & Stress Check-in',
            'Current state & daily streak',
            _showMood,
            (val) => setState(() => _showMood = val),
          ),
          const Divider(height: AppDimens.space12),
          _buildToggleRow(
            '⚡ Quick Action Shortcuts',
            'Scan food, start workout, chat with AI',
            _showShortcuts,
            (val) => setState(() => _showShortcuts = val),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              const SizedBox(height: AppDimens.space2),
              Text(
                subtitle,
                style: context.text.bodySmall?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: _selectedTheme.primaryColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
