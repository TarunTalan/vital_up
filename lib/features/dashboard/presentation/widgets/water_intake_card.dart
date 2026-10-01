import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/water_wave_animation.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/pages/water_trends_page.dart';
import '../cubit/water_intake_cubit.dart';
import '../cubit/water_intake_state.dart';
import 'dashboard_card_header.dart';
import 'trend_widgets.dart';

class WaterIntakeCard extends StatefulWidget {
  const WaterIntakeCard({super.key});

  @override
  State<WaterIntakeCard> createState() => _WaterIntakeCardState();
}

class _WaterIntakeCardState extends State<WaterIntakeCard> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<WaterIntakeCubit, WaterIntakeState>(
      // Keep today's bar in the mini chart in step with the card.
      listenWhen: (previous, current) =>
          current is WaterIntakeLoaded &&
          (previous is! WaterIntakeLoaded ||
              previous.currentIntakeMl != current.currentIntakeMl ||
              previous.dailyGoalMl != current.dailyGoalMl),
      listener: (context, _) =>
          context.read<TrendCubit<WaterLogCache>>().load(),
      child: BlocConsumer<WaterIntakeCubit, WaterIntakeState>(
        listenWhen: (previous, current) {
          if (previous is WaterIntakeLoaded && current is WaterIntakeLoaded) {
            return current.todayLogs.length > previous.todayLogs.length;
          }
          return false;
        },
        listener: (context, state) {
          if (state is WaterIntakeLoaded && state.todayLogs.isNotEmpty) {
            final addedAmount = state.todayLogs.last.amountMl;
            showSuccessSnackBar(
              context,
              'Added $addedAmount ml of water 💧',
              action: SnackBarAction(
                label: 'Undo',
                textColor: context.colors.primary,
                onPressed: () {
                  context.read<WaterIntakeCubit>().undoLast();
                },
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is WaterIntakeLoaded) {
            final percentage = state.dailyGoalMl > 0
                ? (state.currentIntakeMl / state.dailyGoalMl)
                : 0.0;
            return _buildCard(context, state, percentage);
          }
          return AppCard(
            width: double.infinity,
            child: state is WaterIntakeError
                ? DashboardCardError(
                    title: 'Water Intake',
                    iconAsset: 'assets/icons/drop.svg',
                    onRetry: context.read<WaterIntakeCubit>().reload,
                  )
                : const DashboardCardLoading(),
          );
        },
      ),
    );
  }

  Future<void> _openTrends(BuildContext context) async {
    final water = context.read<WaterIntakeCubit>();
    final trend = context.read<TrendCubit<WaterLogCache>>();
    await context.pushNamed('water-trends');
    water.reload();
    trend.load();
  }

  Widget _buildCard(
    BuildContext context,
    WaterIntakeLoaded state,
    double percentage,
  ) {
    final int percentageInt = (percentage * 100).clamp(0, 100).toInt();
    final remainingMl = state.dailyGoalMl - state.currentIntakeMl;
    final isGoalReached = state.currentIntakeMl >= state.dailyGoalMl;

    // Pace calculation (assuming 16 active waking hours 7am - 11pm)
    final now = DateTime.now();
    final currentHour = now.hour.clamp(7, 23);
    final targetPaceFraction = (currentHour - 7) / 16.0;
    final expectedMlByNow = (state.dailyGoalMl * targetPaceFraction).round();
    final isBehindPace = !isGoalReached && (state.currentIntakeMl < expectedMlByNow - 300);

    String statusLabel;
    Color statusColor;
    if (isGoalReached) {
      statusLabel = 'Goal Met 🎉';
      statusColor = AppColors.success;
    } else if (isBehindPace) {
      statusLabel = 'Hydration Nudge ⏰';
      statusColor = AppColors.warning;
    } else {
      statusLabel = 'On Track 💧';
      statusColor = AppColors.teal;
    }

    return Semantics(
      label: '$percentageInt% of daily water goal, ${state.currentIntakeMl} of ${state.dailyGoalMl} milliliters',
      child: AppCard(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardCardHeader(
              title: 'Water Intake',
              iconAsset: 'assets/icons/drop.svg',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_rounded,
                      size: AppDimens.iconMd,
                      color: context.vColors.grayText,
                    ),
                    onPressed: () =>
                        _showEditGoalSheet(context, state.dailyGoalMl),
                    tooltip: 'Edit Daily Goal',
                  ),
                  CardLink(onTap: () => _openTrends(context)),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.cardInnerGap),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    DashboardMetric('${state.currentIntakeMl}'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.space4),
                      child: Text(
                        ' / ${state.dailyGoalMl} ml',
                        style: context.text.bodyMedium
                            ?.copyWith(color: context.vColors.grayText),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space8,
                    vertical: AppDimens.space2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                    border: Border.all(color: statusColor.withAlpha(60)),
                  ),
                  child: Text(
                    statusLabel,
                    style: context.text.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space6),
            Text(
              isGoalReached
                  ? 'Fantastic job staying hydrated today!'
                  : '${remainingMl > 0 ? remainingMl : 0} ml remaining to hit target',
              style: context.text.bodySmall?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            const SizedBox(height: AppDimens.cardInnerGap),
            SizedBox(
              height: context.h(AppDimens.waterWaveHeight),
              child: WaterWaveAnimation(
                fillPercentage: percentage,
                waveColor: AppColors.water,
                backgroundColor: AppColors.water.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: AppDimens.cardInnerGap),
            const MiniTrend<WaterLogCache>(
              color: AppColors.water,
              valueFormatter: WaterTrendsPage.formatMl,
            ),
            const SizedBox(height: AppDimens.cardInnerGap),
            // Quick-add glassware containers
            Row(
              children: [
                _QuickAddButton(
                  amountMl: 150,
                  label: '150ml',
                  subLabel: 'Cup',
                  icon: Icons.local_cafe_outlined,
                  onLogged: () => HapticFeedback.mediumImpact(),
                ),
                const SizedBox(width: AppDimens.space6),
                _QuickAddButton(
                  amountMl: 250,
                  label: '250ml',
                  subLabel: 'Glass',
                  icon: Icons.local_drink_outlined,
                  onLogged: () => HapticFeedback.mediumImpact(),
                ),
                const SizedBox(width: AppDimens.space6),
                _QuickAddButton(
                  amountMl: 500,
                  label: '500ml',
                  subLabel: 'Bottle',
                  icon: Icons.water_drop_outlined,
                  onLogged: () => HapticFeedback.mediumImpact(),
                ),
                const SizedBox(width: AppDimens.space6),
                _QuickAddButton(
                  amountMl: null,
                  label: 'Custom',
                  subLabel: 'Add',
                  icon: Icons.add_rounded,
                  onTapCustom: () => _showCustomAddSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _minGoalMl = 500;

  void _showEditGoalSheet(BuildContext context, int currentGoal) {
    final controller = TextEditingController(text: currentGoal.toString());
    _showNumberInputSheet(
      context: context,
      title: 'Daily Water Goal',
      controller: controller,
      onSave: () {
        final val = int.tryParse(controller.text);
        if (val == null || val < _minGoalMl) {
          return 'Set a goal of at least $_minGoalMl ml';
        }
        context.read<WaterIntakeCubit>().updateGoal(val);
        return null;
      },
    );
  }

  void _showCustomAddSheet(BuildContext context) {
    final controller = TextEditingController();
    _showNumberInputSheet(
      context: context,
      title: 'Log Custom Water',
      controller: controller,
      onSave: () {
        final val = int.tryParse(controller.text);
        if (val == null || val <= 0) return 'Enter an amount in ml';
        context.read<WaterIntakeCubit>().addWater(val);
        HapticFeedback.mediumImpact();
        return null;
      },
    );
  }

  void _showNumberInputSheet({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    required String? Function() onSave,
  }) {
    showAppBottomSheet(
      context: context,
      builder: (sheetContext) => _NumberInputSheet(
        title: title,
        controller: controller,
        onSave: onSave,
      ),
    );
  }
}

class _NumberInputSheet extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final String? Function() onSave;

  const _NumberInputSheet({
    required this.title,
    required this.controller,
    required this.onSave,
  });

  @override
  State<_NumberInputSheet> createState() => _NumberInputSheetState();
}

class _NumberInputSheetState extends State<_NumberInputSheet> {
  String? _error;

  void _save() {
    final error = widget.onSave();
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: context.text.headlineSmall),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
            Divider(height: AppDimens.borderThin, color: context.vColors.divider),
            const SizedBox(height: AppDimens.sectionGap),
            AppTextField.integer(
              label: 'Amount in Milliliters',
              controller: widget.controller,
              hint: 'e.g. 350',
              suffixText: 'ml',
              autofocus: true,
              error: _error,
              onSubmitted: (_) => _save(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppDimens.sectionGap),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppDimens.space16),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Log Water',
                    onTap: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final int? amountMl;
  final String label;
  final String subLabel;
  final IconData icon;
  final VoidCallback? onTapCustom;
  final VoidCallback? onLogged;

  const _QuickAddButton({
    required this.amountMl,
    required this.label,
    required this.subLabel,
    required this.icon,
    this.onTapCustom,
    this.onLogged,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    final isCustom = amountMl == null;

    return Expanded(
      child: Semantics(
        label: 'Add $label of water',
        button: true,
        child: Material(
          color: isCustom
              ? context.vColors.glassFill
              : AppColors.water.withAlpha(25),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: isCustom
                  ? context.vColors.glassBorder!
                  : AppColors.water.withAlpha(50),
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              if (amountMl != null) {
                context.read<WaterIntakeCubit>().addWater(amountMl!);
                onLogged?.call();
              } else if (onTapCustom != null) {
                onTapCustom!();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space4,
                vertical: AppDimens.space10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: AppDimens.iconMd,
                    color: isCustom ? context.colors.onSurface : AppColors.water,
                  ),
                  const SizedBox(height: AppDimens.space4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: context.text.labelSmall?.copyWith(
                        color: isCustom
                            ? context.colors.onSurface
                            : AppColors.water,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    subLabel,
                    maxLines: 1,
                    style: context.text.labelSmall?.copyWith(
                      fontSize: 10,
                      color: context.vColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
