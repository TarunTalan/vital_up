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
  TimeOfDay? _bedTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay? _wakeTime = const TimeOfDay(hour: 7, minute: 0);

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
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
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
             Row(
               children: [
                 if (!isAuto)
                   IconButton(
                     icon: const Icon(Icons.edit_outlined, size: 18),
                     color: const Color(0xFF777777),
                     onPressed: () => context.read<SleepCubit>().showManualEntryForm(),
                     padding: EdgeInsets.zero,
                     constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                   ),
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
                 ),
               ],
             ),
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
    // Calculate duration preview
    String durationText = '';
    if (_bedTime != null && _wakeTime != null) {
      final now = DateTime.now();
      var bDate = DateTime(now.year, now.month, now.day, _bedTime!.hour, _bedTime!.minute);
      var wDate = DateTime(now.year, now.month, now.day, _wakeTime!.hour, _wakeTime!.minute);
      if (wDate.isBefore(bDate)) {
        wDate = wDate.add(const Duration(days: 1));
      }
      final dur = wDate.difference(bDate);
      durationText = _formatDuration(dur);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, 'Sleep', 'assets/icons/sleep.svg'),
        const SizedBox(height: 24),
        Text('Log your sleep', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('We couldn\'t find auto-synced sleep data.', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF777777))),
        const SizedBox(height: 16),
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
            const SizedBox(width: 12),
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
        const SizedBox(height: 16),
        if (durationText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Calculated duration', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF666666))),
                  Text(durationText, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colors.primary)),
                ],
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _bedTime != null && _wakeTime != null
                ? () {
                    final now = DateTime.now();
                    var bDate = DateTime(now.year, now.month, now.day, _bedTime!.hour, _bedTime!.minute);
                    var wDate = DateTime(now.year, now.month, now.day, _wakeTime!.hour, _wakeTime!.minute);
                    context.read<SleepCubit>().saveManualSleep(bDate, wDate);
                  }
                : null,
            child: const Text('Save Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
  final IconData icon;

  const _TimePickerField({
    required this.label,
    required this.time,
    required this.onTimeSelected,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 7, minute: 0),
            builder: (context, child) {
               return Theme(
                 data: theme.copyWith(
                   colorScheme: colors.copyWith(
                     surface: Colors.white, // sleek look
                   ),
                 ),
                 child: child!,
               );
            },
          );
          if (t != null) {
            onTimeSelected(t);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: const Color(0xFF888888)),
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF777777))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                time != null ? time!.format(context) : 'Select',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: time != null ? const Color(0xFF111111) : const Color(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
