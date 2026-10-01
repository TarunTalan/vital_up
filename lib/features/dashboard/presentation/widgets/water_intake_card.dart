import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
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
  bool _isExpanded = false;

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
        // A new log was added.
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
            'Added $addedAmount ml of water',
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

    return Semantics(
      label: '$percentageInt% of daily water goal, ${state.currentIntakeMl} of ${state.dailyGoalMl} milliliters',
      child: AppCard(
        width: double.infinity,
        onTap: () => setState(() => _isExpanded = !_isExpanded),
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
            AnimatedSize(
              duration: AppDurations.slow,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppDimens.cardInnerGap),
                      child: Row(
                        children: [
                          const _QuickAddButton(
                            amountMl: 150,
                            label: '150ml',
                            icon: Icons.local_drink_outlined,
                          ),
                          const SizedBox(width: AppDimens.space8),
                          const _QuickAddButton(
                            amountMl: 250,
                            label: '250ml',
                            icon: Icons.local_cafe_outlined,
                          ),
                          const SizedBox(width: AppDimens.space8),
                          const _QuickAddButton(
                            amountMl: 500,
                            label: '500ml',
                            icon: Icons.water_drop_outlined,
                          ),
                          const SizedBox(width: AppDimens.space8),
                          _QuickAddButton(
                            amountMl: null,
                            label: 'Custom',
                            icon: Icons.add,
                            onTapCustom: () => _showCustomAddSheet(context),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGoalSheet(BuildContext context, int currentGoal) {
    final controller = TextEditingController(text: currentGoal.toString());
    _showNumberInputSheet(
      context: context,
      title: 'Daily Water Goal',
      controller: controller,
      onSave: () {
        final val = int.tryParse(controller.text);
        if (val != null && val > 0) {
          context.read<WaterIntakeCubit>().updateGoal(val);
        }
      },
    );
  }

  void _showCustomAddSheet(BuildContext context) {
    final controller = TextEditingController();
    _showNumberInputSheet(
      context: context,
      title: 'Add Water',
      controller: controller,
      onSave: () {
        final val = int.tryParse(controller.text);
        if (val != null && val > 0) {
          context.read<WaterIntakeCubit>().addWater(val);
        }
      },
    );
  }

  void _showNumberInputSheet({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    required VoidCallback onSave,
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

/// Figma `track/edit/water`: title + close, divider, "Value" field with a
/// unit suffix, Cancel / Save row.
class _NumberInputSheet extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final VoidCallback onSave;

  const _NumberInputSheet({
    required this.title,
    required this.controller,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
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
            Text('Value', style: context.text.titleSmall),
            const SizedBox(height: AppDimens.inputLabelGap),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: const InputDecoration(hintText: '0', suffixText: 'ml'),
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
                    label: 'Save',
                    onTap: () {
                      onSave();
                      Navigator.pop(context);
                    },
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
  final IconData icon;
  final VoidCallback? onTapCustom;

  const _QuickAddButton({
    required this.amountMl,
    required this.label,
    required this.icon,
    this.onTapCustom,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusToast);
    return Expanded(
      child: Semantics(
        label: 'Add $label of water',
        button: true,
        child: Material(
          color: AppColors.water.withValues(alpha: 0.15),
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              if (amountMl != null) {
                context.read<WaterIntakeCubit>().addWater(amountMl!);
              } else if (onTapCustom != null) {
                onTapCustom!();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space4,
                vertical: AppDimens.space8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: AppDimens.iconLg, color: AppColors.water),
                  const SizedBox(height: AppDimens.space4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: context.text.labelSmall?.copyWith(
                        color: AppColors.water,
                        fontWeight: FontWeight.w500,
                      ),
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
