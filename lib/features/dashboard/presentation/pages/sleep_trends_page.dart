import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/sleep_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';

/// Sleep trend: hours per night vs goal, goal stepper, nights list and a
/// manual "Log sleep" entry.
class SleepTrendsPage extends StatelessWidget {
  const SleepTrendsPage({super.key});

  static const _goalStepMin = 30;
  static const _minGoalMin = 240;
  static const _maxGoalMin = 720;

  static String formatHours(double hours) =>
      formatDashboardDuration(Duration(minutes: (hours * 60).round()));

  @override
  Widget build(BuildContext context) {
    final sleep = sl<SleepService>();

    return BlocProvider(
      create: (_) => TrendCubit<SleepSessionInfo>(sl<TrendsService>().sleep)
        ..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<SleepSessionInfo>>();
          return TrendDetailScaffold<SleepSessionInfo>(
            title: 'Sleep',
            color: AppColors.sleep,
            format: formatHours,
            logsTitle: 'Nights',
            bottomBar: AppPrimaryButton(
              label: 'Log sleep',
              onTap: () async {
                final saved = await showAppBottomSheet<bool>(
                  context: context,
                  builder: (_) => const _SleepEntrySheet(),
                );
                if (saved == true) cubit.load();
              },
            ),
            header: (context, data) {
              final goal = sleep.getGoalMinutes();
              Future<void> setGoal(int value) async {
                await sleep.setGoalMinutes(value.clamp(_minGoalMin, _maxGoalMin));
                cubit.load();
              }

              return GoalStepperCard(
                label: 'Nightly goal',
                value: formatDashboardDuration(Duration(minutes: goal)),
                onDecrease: goal > _minGoalMin
                    ? () => setGoal(goal - _goalStepMin)
                    : null,
                onIncrease: goal < _maxGoalMin
                    ? () => setGoal(goal + _goalStepMin)
                    : null,
              );
            },
            logBuilder: (context, night) {
              final time = DateFormat.jm();
              return TrendLogTile(
                icon: night.source == SleepDataSource.healthStore
                    ? Icons.watch_rounded
                    : Icons.bedtime_rounded,
                color: AppColors.sleep,
                title: DateFormat('EEE d MMM').format(night.wakeTime),
                subtitle:
                    '${time.format(night.bedTime)} – ${time.format(night.wakeTime)}'
                    ' · ${night.source == SleepDataSource.healthStore ? 'Synced' : 'Manual'}',
                trailing: formatDashboardDuration(night.duration),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bed / wake time pickers for last night; pops `true` once saved.
class _SleepEntrySheet extends StatefulWidget {
  const _SleepEntrySheet();

  @override
  State<_SleepEntrySheet> createState() => _SleepEntrySheetState();
}

class _SleepEntrySheetState extends State<_SleepEntrySheet> {
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final wake = today.add(Duration(hours: _wake.hour, minutes: _wake.minute));
    var bed = today.add(Duration(hours: _bed.hour, minutes: _bed.minute));
    // Bed time after wake time means it was the previous evening.
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    await sl<SleepService>().saveManualEntry(bed, wake);
    if (mounted) Navigator.pop(context, true);
  }

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
            Text('Log last night', style: context.text.headlineSmall),
            const SizedBox(height: AppDimens.sectionGap),
            Row(
              children: [
                Expanded(
                  child: SleepTimePickerField(
                    label: 'Bed Time',
                    time: _bed,
                    icon: Icons.nightlight_round,
                    onTimeSelected: (t) => setState(() => _bed = t),
                  ),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: SleepTimePickerField(
                    label: 'Wake Time',
                    time: _wake,
                    icon: Icons.wb_sunny_rounded,
                    onTimeSelected: (t) => setState(() => _wake = t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Save',
              isLoading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
