import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_log_rules.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/log_workout.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// Log a workout that already happened (gym, class, match): type, when,
/// how long and how hard. Returns whether one was saved.
Future<bool> showLogWorkoutSheet(
  BuildContext context, {
  ActivityType? initialType,
}) async {
  final saved = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => _LogWorkoutSheet(initialType: initialType),
  );
  return saved == true;
}

/// One-tap lengths offered above the minutes field.
const workoutLengthPresets = [15, 30, 45, 60, 90];

class _LogWorkoutSheet extends StatefulWidget {
  final ActivityType? initialType;

  const _LogWorkoutSheet({this.initialType});

  @override
  State<_LogWorkoutSheet> createState() => _LogWorkoutSheetState();
}

class _LogWorkoutSheetState extends State<_LogWorkoutSheet> {
  late ActivityType _type;
  late DateTime _day;
  late TimeOfDay _startTime;
  final _minutes = TextEditingController(text: '45');
  WorkoutIntensity _intensity = WorkoutIntensity.moderate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialType;
    _type = initial != null && !initial.isGpsBased
        ? initial
        : ActivityType.strength;
    // Default: a 45 minute workout that just ended, on a 5 minute mark.
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 45));
    _day = startOfDay(start);
    _startTime = TimeOfDay(
      hour: start.hour,
      minute: start.minute - start.minute % 5,
    );
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  DateTime get _start => DateTime(
    _day.year,
    _day.month,
    _day.day,
    _startTime.hour,
    _startTime.minute,
  );

  /// Typed minutes, or null when empty or not a whole number in range.
  int? get _lengthMinutes => parseNumberInRange(
    _minutes.text,
    min: 1,
    max: WorkoutLogRules.maxLength.inMinutes.toDouble(),
  )?.round();

  Future<void> _pickDay() async {
    final today = startOfDay(DateTime.now());
    final first = DateTime(
      today.year,
      today.month,
      today.day - WorkoutLogRules.maxBackfillDays,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(first)
          ? first
          : (_day.isAfter(today) ? today : _day),
      firstDate: first,
      lastDate: today,
      helpText: 'Workout date',
    );
    if (picked != null && mounted) {
      setState(() {
        _day = startOfDay(picked);
        _error = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Start time',
    );
    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final minutes = _lengthMinutes;
    if (minutes == null) {
      setState(() => _error = 'Enter how long it lasted, 1 to 360 minutes.');
      return;
    }
    final length = Duration(minutes: minutes);
    final error = workoutEntryError(_start, length, now: DateTime.now());
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    try {
      await sl<LogWorkout>()(
        type: _type,
        start: _start,
        length: length,
        intensity: _intensity,
      );
    } catch (e) {
      debugPrint('Logging workout failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save your workout. Try again.";
      });
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  String get _dayLabel {
    final now = DateTime.now();
    if (isSameDay(_day, now)) return 'Today';
    if (isSameDay(_day, previousDay(startOfDay(now)))) return 'Yesterday';
    return DateFormat('EEE d MMM').format(_day);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final typed = _lengthMinutes;
    return TrackerSheet(
      metric: TrackerMetric.activity,
      title: 'Log a workout',
      subtitle: 'Add a session you did without tracking it',
      action: AppPrimaryButton(
        label: 'Save workout',
        isLoading: _saving,
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppCaption('Workout'),
          const SizedBox(height: AppDimens.space8),
          WorkoutTypePicker(
            selected: _type,
            onSelected: (type) => setState(() => _type = type),
          ),
          const SizedBox(height: AppDimens.sectionGap),
          const AppCaption('Started'),
          const SizedBox(height: AppDimens.space8),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.event_rounded, size: AppDimens.iconXs),
                label: Text(_dayLabel),
                onPressed: _pickDay,
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.schedule_rounded,
                  size: AppDimens.iconXs,
                ),
                label: Text(_startTime.format(context)),
                onPressed: _pickTime,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sectionGap),
          const AppCaption('Duration'),
          const SizedBox(height: AppDimens.space8),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: [
              for (final preset in workoutLengthPresets)
                ChoiceChip(
                  label: Text('$preset min'),
                  selected: typed == preset,
                  onSelected: (_) => setState(() {
                    _minutes.text = '$preset';
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          AppTextField.integer(
            controller: _minutes,
            label: 'Minutes',
            suffixText: 'min',
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: AppDimens.sectionGap),
          const AppCaption('Intensity'),
          const SizedBox(height: AppDimens.space8),
          WorkoutIntensityPicker(
            selected: _intensity,
            onChanged: (value) => setState(() => _intensity = value),
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            _intensity.hint,
            style: context.text.bodySmall?.copyWith(color: v.grayText),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: AppDimens.space12),
            Text(
              error,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chips for the workout types without a route.
class WorkoutTypePicker extends StatelessWidget {
  final ActivityType selected;
  final ValueChanged<ActivityType> onSelected;

  const WorkoutTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.space8,
      runSpacing: AppDimens.space8,
      children: [
        for (final type in ActivityType.workouts)
          ChoiceChip(
            avatar: Icon(activityTypeIcon(type), size: AppDimens.iconXs),
            label: Text(type.label),
            selected: selected == type,
            onSelected: (_) => onSelected(type),
          ),
      ],
    );
  }
}

/// Light / Moderate / Hard.
class WorkoutIntensityPicker extends StatelessWidget {
  final WorkoutIntensity selected;
  final ValueChanged<WorkoutIntensity> onChanged;

  const WorkoutIntensityPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl<WorkoutIntensity>(
      values: WorkoutIntensity.values,
      selected: selected,
      label: (value) => value.label,
      onChanged: onChanged,
    );
  }
}

extension WorkoutIntensityHint on WorkoutIntensity {
  /// One line on how each level feels, under the picker.
  String get hint => switch (this) {
    WorkoutIntensity.light => 'Easy pace, you could chat the whole time',
    WorkoutIntensity.moderate => 'Breathing harder, you could still talk',
    WorkoutIntensity.hard => 'Hard to say more than a few words',
  };
}
