import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../cubit/sleep_cubit.dart';
import '../cubit/sleep_state.dart';

class SleepCard extends StatefulWidget {
  const SleepCard({super.key});

  @override
  State<SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends State<SleepCard> {
  TimeOfDay? _bedTime;
  TimeOfDay? _wakeTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFD8D8D8).withValues(alpha: 0.78),
        ),
      ),
      child: BlocBuilder<SleepCubit, SleepState>(
        builder: (context, state) {
          if (state is SleepLoading || state is SleepInitial) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            );
          } else if (state is SleepError) {
            return _buildErrorState(context, theme, state.message);
          } else if (state is SleepNeedsHealthConnectInstall) {
            return _buildHealthConnectState(context, theme, colors);
          } else if (state is SleepLoadedAuto) {
            return _buildLoadedState(context, theme, state.session.duration, state.session.bedTime, state.session.wakeTime, true);
          } else if (state is SleepLoadedManual) {
            return _buildLoadedState(context, theme, state.session.duration, state.session.bedTime, state.session.wakeTime, false);
          } else if (state is SleepNeedsManualEntry) {
            return _buildManualEntryForm(context, theme, colors);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildHealthConnectState(BuildContext context, ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, 'Sleep', 'assets/icons/sleep.svg'),
        const SizedBox(height: 24),
        Text(
          'Health Connect Required',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'To auto-sync sleep data, please install or update Health Connect.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF777777),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(
              onPressed: () {
                context.read<SleepCubit>().installHealthConnect();
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
              ),
              child: const Text('Install'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                context.read<SleepCubit>().showManualEntryForm();
              },
              child: const Text('Enter Manually'),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             _buildHeader(theme, 'Sleep', 'assets/icons/sleep.svg'),
             TextButton(
               onPressed: () => context.read<SleepCubit>().showManualEntryForm(),
               child: const Text('Manual Entry'),
             )
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Error loading data',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF777777)),
        ),
      ],
    );
  }

  Widget _buildLoadedState(BuildContext context, ThemeData theme, Duration duration, DateTime bedTime, DateTime wakeTime, bool isAuto) {
    final formattedTotal = _formatDuration(duration);
    final timeFormat = DateFormat.jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             _buildHeader(theme, 'Sleep', 'assets/icons/sleep.svg'),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: isAuto ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Text(
                 isAuto ? 'Auto-synced' : 'Manual Entry',
                 style: theme.textTheme.labelSmall?.copyWith(
                   color: isAuto ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                   fontWeight: FontWeight.w600,
                 ),
               ),
             )
          ],
        ),
        const SizedBox(height: 24),
        Text(
          formattedTotal,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 36,
            height: 1,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bed time', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF777777))),
                Text(timeFormat.format(bedTime), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(width: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wake time', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF777777))),
                Text(timeFormat.format(wakeTime), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        )
      ],
    );
  }

  Widget _buildManualEntryForm(BuildContext context, ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, 'Sleep', 'assets/icons/sleep.svg'),
        const SizedBox(height: 24),
        Text('Add manual entry', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TimePickerField(
                label: 'Bed Time',
                time: _bedTime,
                onTimeSelected: (t) => setState(() => _bedTime = t),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TimePickerField(
                label: 'Wake Time',
                time: _wakeTime,
                onTimeSelected: (t) => setState(() => _wakeTime = t),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _bedTime != null && _wakeTime != null
                ? () {
                    final now = DateTime.now();
                    var bDate = DateTime(now.year, now.month, now.day, _bedTime!.hour, _bedTime!.minute);
                    var wDate = DateTime(now.year, now.month, now.day, _wakeTime!.hour, _wakeTime!.minute);
                    
                    // the service layer handles midnight rollover if wakeTime < bedTime
                    context.read<SleepCubit>().saveManualSleep(bDate, wDate);
                  }
                : null,
            child: const Text('Save Entry'),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, String title, String iconAsset) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFD8F2DC),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: 23,
              height: 23,
              colorFilter: const ColorFilter.mode(
                Color(0xFF111111),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF161616),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onTimeSelected;

  const _TimePickerField({
    required this.label,
    required this.time,
    required this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 7, minute: 0),
        );
        if (t != null) {
          onTimeSelected(t);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF777777))),
            const SizedBox(height: 4),
            Text(
              time != null ? time!.format(context) : 'Select time',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: time != null ? const Color(0xFF111111) : const Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
