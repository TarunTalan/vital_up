import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/circular_sleep_clock.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import '../cubit/sleep_cubit.dart';
import '../cubit/sleep_state.dart';
import '../cubit/trend_cubit.dart';
import '../../domain/entities/sleep_session_info.dart';
import 'trend_widgets.dart';
import 'dashboard_card_header.dart';

const _title = 'Sleep';
const _icon = 'assets/icons/moon_stars.svg';

class SleepCard extends StatefulWidget {
  const SleepCard({super.key});

  @override
  State<SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends State<SleepCard> {
  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: AnimatedSize(
        duration: AppDurations.slow,
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: BlocConsumer<SleepCubit, SleepState>(
          // A saved manual entry changes last night's bar.
          listenWhen: (_, state) =>
              state is SleepLoadedAuto || state is SleepLoadedManual,
          listener: (context, _) =>
              context.read<TrendCubit<SleepSessionInfo>>().load(),
          builder: (context, state) {
            if (state is SleepLoading || state is SleepInitial) {
              return const DashboardCardLoading();
            } else if (state is SleepError) {
              return _buildErrorState(context, state.message);
            } else if (state is SleepNeedsHealthConnectInstall) {
              return _buildHealthConnectState(context);
            } else if (state is SleepLoadedAuto) {
              return _buildLoadedState(context, state.session, true);
            } else if (state is SleepLoadedManual) {
              return _buildLoadedState(context, state.session, false);
            } else if (state is SleepNeedsManualEntry) {
              return _buildManualEntryForm(context);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildHealthConnectState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardCardHeader(title: _title, iconAsset: _icon),
        const SizedBox(height: AppDimens.cardInnerGap),
        Text('Health Connect Required', style: context.text.titleSmall),
        const SizedBox(height: AppDimens.space8),
        Text(
          'To auto-sync sleep data, please install or update Health Connect.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.vColors.grayText),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        Wrap(
          spacing: AppDimens.space8,
          runSpacing: AppDimens.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppPrimaryButton(
              label: 'Install',
              expand: false,
              onTap: () => context.read<SleepCubit>().installHealthConnect(),
            ),
            TextButton(
              onPressed: () => context.read<SleepCubit>().showManualEntryForm(),
              child: const Text('Enter Manually'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCardHeader(
          title: _title,
          iconAsset: _icon,
          trailing: TextButton(
            onPressed: () => context.read<SleepCubit>().showManualEntryForm(),
            child: const Text('Manual Entry'),
          ),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        LoadErrorView(onRetry: context.read<SleepCubit>().loadSleepData),
      ],
    );
  }

  Widget _buildLoadedState(
      BuildContext context, SleepSessionInfo session, bool isAuto) {
    final v = context.vColors;
    final timeFormat = DateFormat.jm();
    final chipColor = isAuto ? v.success! : v.warning!;
    final chipFill = isAuto ? v.successTint : v.warningTint;
    final score = session.sleepScore;

    Color scoreColor;
    if (score >= 85) {
      scoreColor = AppColors.success;
    } else if (score >= 70) {
      scoreColor = AppColors.teal;
    } else if (score >= 50) {
      scoreColor = AppColors.warning;
    } else {
      scoreColor = AppColors.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCardHeader(
          title: _title,
          iconAsset: _icon,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.mode_edit_outline_rounded,
                    size: AppDimens.iconSm),
                color: v.grayText,
                tooltip: 'Log / Edit Sleep',
                onPressed: () => _openSleepClockSheet(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppDimens.iconXl,
                  minHeight: AppDimens.iconXl,
                ),
              ),
              CardLink(onTap: () => _openTrends(context)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space8,
                  vertical: AppDimens.space4,
                ),
                decoration: BoxDecoration(
                  color: chipFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                ),
                child: Text(
                  isAuto ? 'Auto-synced' : 'Manual',
                  style: context.text.labelSmall?.copyWith(
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            DashboardMetric(formatDashboardDuration(session.duration)),
            const SizedBox(width: AppDimens.space12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space10,
                vertical: AppDimens.space4,
              ),
              decoration: BoxDecoration(
                color: scoreColor.withAlpha(30),
                borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                border: Border.all(color: scoreColor.withAlpha(60)),
              ),
              child: Text(
                'Score: $score% · ${session.scoreCategory}',
                style: context.text.labelSmall?.copyWith(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        Wrap(
          spacing: AppDimens.space32,
          runSpacing: AppDimens.space8,
          children: [
            _TimeStat(
                label: 'Bed time',
                value: timeFormat.format(session.bedTime),
                icon: Icons.nightlight_round,
                color: AppColors.sleep),
            _TimeStat(
                label: 'Wake time',
                value: timeFormat.format(session.wakeTime),
                icon: Icons.wb_sunny_rounded,
                color: AppColors.warning),
          ],
        ),
        if (session.hasStages) ...[
          const SizedBox(height: AppDimens.space12),
          _SleepStagesBar(session: session),
        ],
        const SizedBox(height: AppDimens.cardInnerGap),
        MiniTrend<SleepSessionInfo>(
          color: AppColors.sleep,
          valueFormatter: (h) =>
              formatDashboardDuration(Duration(minutes: (h * 60).round())),
        ),
      ],
    );
  }

  Future<void> _openSleepClockSheet(BuildContext context) async {
    final cubit = context.read<SleepCubit>();
    final saved = await showAppBottomSheet<bool>(
      context: context,
      builder: (_) => const _SleepClockDialog(),
    );
    if (saved == true) {
      cubit.loadSleepData();
    }
  }

  Future<void> _openTrends(BuildContext context) async {
    final sleep = context.read<SleepCubit>();
    final trend = context.read<TrendCubit<SleepSessionInfo>>();
    await context.pushNamed('sleep-trends');
    sleep.loadSleepData();
    trend.load();
  }

  Widget _buildManualEntryForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCardHeader(
          title: _title,
          iconAsset: _icon,
          trailing: CardLink(onTap: () => _openTrends(context)),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        Text('Log your sleep', style: context.text.titleSmall),
        const SizedBox(height: AppDimens.space4),
        Text(
          'Quickly adjust bedtime and wake up on the circular dial.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.vColors.grayText),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        CircularSleepClockPicker(
          initialBedTime: _bedTime,
          initialWakeTime: _wakeTime,
          onChanged: (bed, wake) {
            setState(() {
              _bedTime = bed;
              _wakeTime = wake;
            });
          },
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        AppPrimaryButton(
          label: 'Save Sleep Entry',
          onTap: () {
            final now = DateTime.now();
            var bDate = DateTime(
                now.year, now.month, now.day, _bedTime.hour, _bedTime.minute);
            var wDate = DateTime(
                now.year, now.month, now.day, _wakeTime.hour, _wakeTime.minute);
            if (!bDate.isBefore(wDate)) {
              bDate = bDate.subtract(const Duration(days: 1));
            }
            context.read<SleepCubit>().saveManualSleep(bDate, wDate);
          },
        ),
      ],
    );
  }
}

class _SleepStagesBar extends StatelessWidget {
  final SleepSessionInfo session;

  const _SleepStagesBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final deep = session.deepSleepMinutes ?? 0;
    final rem = session.remSleepMinutes ?? 0;
    final light = session.lightSleepMinutes ?? 0;
    final awake = session.awakeMinutes ?? 0;
    final total = deep + rem + light + awake;

    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (deep > 0)
                  Expanded(
                    flex: deep,
                    child: Container(color: const Color(0xFF4A148C)),
                  ),
                if (rem > 0)
                  Expanded(
                    flex: rem,
                    child: Container(color: const Color(0xFF7B1FA2)),
                  ),
                if (light > 0)
                  Expanded(
                    flex: light,
                    child: Container(color: AppColors.teal),
                  ),
                if (awake > 0)
                  Expanded(
                    flex: awake,
                    child: Container(color: AppColors.warning),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.space6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StageDot(label: 'Deep: ${deep}m', color: const Color(0xFF4A148C)),
            _StageDot(label: 'REM: ${rem}m', color: const Color(0xFF7B1FA2)),
            _StageDot(label: 'Light: ${light}m', color: AppColors.teal),
            if (awake > 0)
              _StageDot(label: 'Awake: ${awake}m', color: AppColors.warning),
          ],
        ),
      ],
    );
  }
}

class _StageDot extends StatelessWidget {
  final String label;
  final Color color;

  const _StageDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            fontSize: 10,
            color: context.vColors.grayText,
          ),
        ),
      ],
    );
  }
}

class _TimeStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TimeStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimens.space6),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: AppDimens.iconXs, color: color),
        ),
        const SizedBox(width: AppDimens.space8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.text.labelSmall
                  ?.copyWith(color: context.vColors.grayText),
            ),
            Text(
              value,
              style: context.text.titleSmall
                  ?.copyWith(color: context.colors.onSurface),
            ),
          ],
        ),
      ],
    );
  }
}

class _SleepClockDialog extends StatefulWidget {
  const _SleepClockDialog();

  @override
  State<_SleepClockDialog> createState() => _SleepClockDialogState();
}

class _SleepClockDialogState extends State<_SleepClockDialog> {
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final wake = today.add(Duration(hours: _wake.hour, minutes: _wake.minute));
    var bed = today.add(Duration(hours: _bed.hour, minutes: _bed.minute));
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    await context.read<SleepCubit>().saveManualSleep(bed, wake);
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Log Sleep Interval', style: context.text.headlineSmall),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space12),
            CircularSleepClockPicker(
              initialBedTime: _bed,
              initialWakeTime: _wake,
              onChanged: (b, w) {
                setState(() {
                  _bed = b;
                  _wake = w;
                });
              },
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Save Sleep',
              isLoading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
