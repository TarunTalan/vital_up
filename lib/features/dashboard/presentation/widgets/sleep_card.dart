import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import '../cubit/sleep_cubit.dart';
import '../cubit/sleep_state.dart';
import 'dashboard_card_header.dart';

const _title = 'Sleep';
const _icon = 'assets/icons/moon_stars.svg';

class SleepCard extends StatefulWidget {
  const SleepCard({super.key});

  @override
  State<SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends State<SleepCard> {
  TimeOfDay? _bedTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay? _wakeTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: AnimatedSize(
        duration: AppDurations.slow,
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: BlocBuilder<SleepCubit, SleepState>(
          builder: (context, state) {
            if (state is SleepLoading || state is SleepInitial) {
              return const DashboardCardLoading();
            } else if (state is SleepError) {
              return _buildErrorState(context, state.message);
            } else if (state is SleepNeedsHealthConnectInstall) {
              return _buildHealthConnectState(context);
            } else if (state is SleepLoadedAuto) {
              return _buildLoadedState(context, state.session.duration,
                  state.session.bedTime, state.session.wakeTime, true);
            } else if (state is SleepLoadedManual) {
              return _buildLoadedState(context, state.session.duration,
                  state.session.bedTime, state.session.wakeTime, false);
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
        Text(
          'Error loading data',
          style: context.text.bodyMedium?.copyWith(color: context.colors.error),
        ),
        const SizedBox(height: AppDimens.space8),
        Text(
          message,
          style: context.text.bodySmall
              ?.copyWith(color: context.vColors.grayText),
        ),
      ],
    );
  }

  Widget _buildLoadedState(BuildContext context, Duration duration,
      DateTime bedTime, DateTime wakeTime, bool isAuto) {
    final v = context.vColors;
    final timeFormat = DateFormat.jm();
    final chipColor = isAuto ? v.success! : v.warning!;
    final chipFill = isAuto ? v.successTint : v.warningTint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCardHeader(
          title: _title,
          iconAsset: _icon,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAuto)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: AppDimens.iconSm),
                  color: v.grayText,
                  tooltip: 'Edit',
                  onPressed: () =>
                      context.read<SleepCubit>().showManualEntryForm(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppDimens.iconXl,
                    minHeight: AppDimens.iconXl,
                  ),
                ),
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
                  isAuto ? 'Auto-synced' : 'Manual Entry',
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
        DashboardMetric(formatDashboardDuration(duration)),
        const SizedBox(height: AppDimens.cardInnerGap),
        Wrap(
          spacing: AppDimens.space32,
          runSpacing: AppDimens.space8,
          children: [
            _TimeStat(label: 'Bed time', value: timeFormat.format(bedTime)),
            _TimeStat(label: 'Wake time', value: timeFormat.format(wakeTime)),
          ],
        ),
      ],
    );
  }

  Widget _buildManualEntryForm(BuildContext context) {
    String durationText = '';
    if (_bedTime != null && _wakeTime != null) {
      final now = DateTime.now();
      var bDate = DateTime(now.year, now.month, now.day, _bedTime!.hour, _bedTime!.minute);
      var wDate = DateTime(now.year, now.month, now.day, _wakeTime!.hour, _wakeTime!.minute);
      if (wDate.isBefore(bDate)) {
        wDate = wDate.add(const Duration(days: 1));
      }
      durationText = formatDashboardDuration(wDate.difference(bDate));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardCardHeader(title: _title, iconAsset: _icon),
        const SizedBox(height: AppDimens.cardInnerGap),
        Text('Log your sleep', style: context.text.titleSmall),
        const SizedBox(height: AppDimens.space4),
        Text(
          'We couldn\'t find auto-synced sleep data.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.vColors.grayText),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        Row(
          children: [
            Expanded(
              child: _TimePickerField(
                label: 'Bed Time',
                time: _bedTime,
                onTimeSelected: (t) => setState(() => _bedTime = t),
                icon: Icons.nightlight_round,
              ),
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: _TimePickerField(
                label: 'Wake Time',
                time: _wakeTime,
                onTimeSelected: (t) => setState(() => _wakeTime = t),
                icon: Icons.wb_sunny_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        if (durationText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.cardInnerGap),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space16,
                vertical: AppDimens.space12,
              ),
              decoration: BoxDecoration(
                color: context.vColors.primaryFill,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calculated duration',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.vColors.grayText),
                    ),
                  ),
                  Text(
                    durationText,
                    style: context.text.titleSmall
                        ?.copyWith(color: context.colors.primary),
                  ),
                ],
              ),
            ),
          ),
        AppPrimaryButton(
          label: 'Save Entry',
          enabled: _bedTime != null && _wakeTime != null,
          onTap: () {
            if (_bedTime == null || _wakeTime == null) return;
            final now = DateTime.now();
            var bDate = DateTime(now.year, now.month, now.day, _bedTime!.hour, _bedTime!.minute);
            var wDate = DateTime(now.year, now.month, now.day, _wakeTime!.hour, _wakeTime!.minute);
            context.read<SleepCubit>().saveManualSleep(bDate, wDate);
          },
        ),
      ],
    );
  }
}

class _TimeStat extends StatelessWidget {
  final String label;
  final String value;

  const _TimeStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.text.bodyMedium
              ?.copyWith(color: context.vColors.grayText),
        ),
        Text(
          value,
          style: context.text.titleSmall
              ?.copyWith(color: context.colors.onSurface),
        ),
      ],
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onTimeSelected;
  final IconData icon;

  const _TimePickerField({
    required this.label,
    required this.time,
    required this.onTimeSelected,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final radius = BorderRadius.circular(AppDimens.radiusCard);

    return Material(
      color: v.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: v.glassBorder!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 7, minute: 0),
          );
          if (t != null) {
            onTimeSelected(t);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space12,
            vertical: AppDimens.space12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: AppDimens.iconXs, color: v.grayText),
                  const SizedBox(width: AppDimens.space6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall
                          ?.copyWith(color: v.grayText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  time != null ? time!.format(context) : 'Select',
                  style: context.text.titleMedium?.copyWith(
                    color: time != null
                        ? context.colors.onSurface
                        : v.grayText,
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
