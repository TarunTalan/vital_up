import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/circular_sleep_clock.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/domain/tracker_input_rules.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/mood_widgets.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';

// ---------------------------------------------------------------------------
// Water
// ---------------------------------------------------------------------------

/// Common drink sizes offered as one-tap presets.
const waterPresets = [
  (ml: 150, label: 'Cup', icon: Icons.local_cafe_rounded),
  (ml: 250, label: 'Glass', icon: Icons.local_drink_rounded),
  (ml: 500, label: 'Bottle', icon: Icons.water_drop_rounded),
  (ml: 750, label: 'Large', icon: Icons.sports_bar_rounded),
];

/// Log water: tap a preset to add it straight away, or type an amount.
/// [onAdd] returns whether the drink was saved (a throw counts as not
/// saved). Returns the millilitres added, or null.
Future<int?> showWaterLogSheet(
  BuildContext context, {
  required Future<bool> Function(int ml) onAdd,
}) {
  return showAppBottomSheet<int>(
    context: context,
    builder: (_) => _WaterLogSheet(onAdd: onAdd),
  );
}

class _WaterLogSheet extends StatefulWidget {
  final Future<bool> Function(int ml) onAdd;

  const _WaterLogSheet({required this.onAdd});

  @override
  State<_WaterLogSheet> createState() => _WaterLogSheetState();
}

class _WaterLogSheetState extends State<_WaterLogSheet> {
  final _custom = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _add(int ml) async {
    // One drink per tap, however fast the taps come.
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    var saved = false;
    try {
      saved = await widget.onAdd(ml);
    } catch (e) {
      debugPrint('Water not saved: $e');
    }
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, ml);
    } else {
      setState(() {
        _saving = false;
        _error = "Couldn't add water. Try again.";
      });
    }
  }

  void _addCustom() {
    final ml = parseWaterAmount(_custom.text);
    if (ml == null) {
      setState(() => _error = waterAmountError);
      return;
    }
    _add(ml);
  }

  @override
  Widget build(BuildContext context) {
    const metric = TrackerMetric.water;
    return TrackerSheet(
      metric: metric,
      title: 'Log water',
      subtitle: 'Tap a size to add it',
      action: AppPrimaryButton(
        label: 'Add amount',
        isLoading: _saving,
        onTap: _addCustom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrackerPresetRow(
            children: [
              for (final p in waterPresets)
                TrackerPresetTile(
                  icon: p.icon,
                  label: '${p.ml} ml',
                  caption: p.label,
                  color: metric.color,
                  onTap: () => _add(p.ml),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.sectionGap),
          AppTextField(
            label: 'Custom amount',
            controller: _custom,
            hint: 'e.g. 350',
            suffixText: 'ml',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(waterAmountMaxDigits),
            ],
            textInputAction: TextInputAction.done,
            enabled: !_saving,
            error: _error,
            onSubmitted: (_) => _addCustom(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mood
// ---------------------------------------------------------------------------

/// Check in: pick how you feel, optionally what's behind it. Returns true
/// once saved. Pass [initial] to edit today's check-in.
Future<bool> showMoodLogSheet(
  BuildContext context, {
  StressCheckIn? initial,
  int? level,
}) async {
  final saved = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => _MoodLogSheet(
      initialLevel: level ?? initial?.level,
      initialTags: {...?initial?.tags},
    ),
  );
  return saved == true;
}

class _MoodLogSheet extends StatefulWidget {
  final int? initialLevel;
  final Set<StressTag> initialTags;

  const _MoodLogSheet({this.initialLevel, this.initialTags = const {}});

  @override
  State<_MoodLogSheet> createState() => _MoodLogSheetState();
}

class _MoodLogSheetState extends State<_MoodLogSheet> {
  late int? _level = widget.initialLevel;
  late final Set<StressTag> _tags = {...widget.initialTags};
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final level = _level;
    if (level == null || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await sl<VitaRepository>().saveStressCheckIn(
        level,
        tags: StressTag.values.where(_tags.contains).toList(),
      );
    } catch (e) {
      debugPrint('Mood check-in not saved: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save your check-in. Try again.";
      });
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    return TrackerSheet(
      metric: TrackerMetric.mood,
      title: 'How are you feeling?',
      subtitle: 'One check-in a day builds your streak',
      action: AppPrimaryButton(
        label: 'Save check-in',
        enabled: level != null,
        isLoading: _saving,
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoodLevelPicker(
            selected: level,
            onSelected: (l) => setState(() => _level = l),
          ),
          const SizedBox(height: AppDimens.sectionGap),
          Text(
            "What's on your mind? (optional)",
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          StressTagPicker(
            selected: _tags,
            onToggle: (tag) => setState(() {
              if (!_tags.remove(tag)) _tags.add(tag);
            }),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: AppDimens.space12),
            Text(
              error,
              textAlign: TextAlign.center,
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

/// Five faces from very calm to very stressed, with the chosen label.
class MoodLevelPicker extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelected;

  const MoodLevelPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final level = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var l = 1; l <= 5; l++)
              AnimatedMoodFace(
                icon: moodIcon(l),
                label: StressCheckIn.labels[l - 1],
                color: stressColor(l),
                selected: level == l,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(l);
                },
              ),
          ],
        ),
        const SizedBox(height: AppDimens.space12),
        AnimatedSwitcher(
          duration: AppDurations.fast,
          child: Text(
            level == null
                ? 'Tap a face to check in'
                : StressCheckIn.labels[level - 1],
            key: ValueKey(level),
            textAlign: TextAlign.center,
            style: context.text.titleSmall?.copyWith(
              color: level == null
                  ? context.vColors.grayText
                  : stressColor(level),
            ),
          ),
        ),
      ],
    );
  }
}

/// Toggleable check-in tags with icons.
class StressTagPicker extends StatelessWidget {
  final Set<StressTag> selected;
  final ValueChanged<StressTag> onToggle;

  const StressTagPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.space8,
      runSpacing: AppDimens.space8,
      children: [
        for (final tag in StressTag.values)
          FilterChip(
            avatar: Icon(tag.icon, size: AppDimens.iconXs),
            label: Text(tag.label),
            selected: selected.contains(tag),
            showCheckmark: false,
            onSelected: (_) => onToggle(tag),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sleep
// ---------------------------------------------------------------------------

/// Log a night on the bedtime / wake-up dial, for last night or an earlier
/// one, starting from [initial] (e.g. the phone's estimate) when given.
/// Returns true once saved.
Future<bool> showSleepLogSheet(
  BuildContext context, {
  SleepSessionInfo? initial,
}) async {
  final saved = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => SleepLogSheet(initial: initial),
  );
  return saved == true;
}

class SleepLogSheet extends StatefulWidget {
  final SleepSessionInfo? initial;

  /// Nightly goal in minutes (from [SleepService] when not given).
  final int? goalMinutes;

  const SleepLogSheet({super.key, this.initial, this.goalMinutes});

  @override
  State<SleepLogSheet> createState() => _SleepLogSheetState();
}

class _SleepLogSheetState extends State<SleepLogSheet> {
  late TimeOfDay _bed;
  late TimeOfDay _wake;

  /// Day the night ended (woke up).
  late DateTime _wakeDay;
  bool _saving = false;
  String? _error;

  /// Height added so the clock keeps [CircularSleepClockPicker.minClockSize]
  /// (0 unless the screen is very short at large text).
  double _extraHeight = 0;

  /// Time asleep for the night as it was opened, when it's less than
  /// time in bed (a phone estimate leaves out screen-on check-ins). Shown
  /// and saved while the times stay as they were.
  Duration? _initialAsleep;
  late final TimeOfDay _initialBed;
  late final TimeOfDay _initialWake;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _bed = TimeOfDay.fromDateTime(initial.bedTime);
      _wake = TimeOfDay.fromDateTime(initial.wakeTime);
      _wakeDay = startOfDay(initial.wakeTime);
      final span = initial.wakeTime.difference(initial.bedTime);
      if (initial.duration > Duration.zero && initial.duration < span) {
        _initialAsleep = initial.duration;
      }
    } else {
      final now = DateTime.now();
      final usualWake = DateTime(now.year, now.month, now.day, 7);
      if (now.isBefore(usualWake)) {
        // Logging early (up at 6:10): wake up now, in bed for the goal,
        // instead of a 7:00 wake-up that would be in the future.
        final wake = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute - now.minute % 5,
        );
        final goal = Duration(
          minutes: widget.goalMinutes ?? sl<SleepService>().getGoalMinutes(),
        );
        final inBed = goal < minSleepEntry
            ? minSleepEntry
            : goal > maxSleepEntry
            ? maxSleepEntry
            : goal;
        _bed = TimeOfDay.fromDateTime(wake.subtract(inBed));
        _wake = TimeOfDay.fromDateTime(wake);
      } else {
        _bed = const TimeOfDay(hour: 23, minute: 0);
        _wake = const TimeOfDay(hour: 7, minute: 0);
      }
      _wakeDay = startOfDay(now);
    }
    _initialBed = _bed;
    _initialWake = _wake;
  }

  /// The opened night's time asleep, while its times are unchanged.
  Duration? get _keptAsleep =>
      _bed == _initialBed && _wake == _initialWake ? _initialAsleep : null;

  Duration get _duration {
    final kept = _keptAsleep;
    if (kept != null) return kept;
    final (:bed, :wake) = _times;
    return wake.difference(bed);
  }

  Future<void> _pickDay() async {
    final today = startOfDay(DateTime.now());
    final first = DateTime(today.year, today.month, today.day - 30);
    final picked = await showDatePicker(
      context: context,
      // The picker asserts its initial date is within range.
      initialDate: _wakeDay.isBefore(first)
          ? first
          : _wakeDay.isAfter(today)
          ? today
          : _wakeDay,
      firstDate: first,
      lastDate: today,
      helpText: 'Night ending on',
    );
    if (picked != null && mounted) {
      setState(() {
        _wakeDay = startOfDay(picked);
        _error = null;
      });
    }
  }

  ({DateTime bed, DateTime wake}) get _times => sleepEntryTimes(
    _wakeDay,
    bedMinutes: _bed.hour * 60 + _bed.minute,
    wakeMinutes: _wake.hour * 60 + _wake.minute,
  );

  Future<void> _save() async {
    if (_saving) return;
    final (:bed, :wake) = _times;
    final error = sleepEntryError(bed, wake, now: DateTime.now());
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      // Unchanged times keep the opened night's time asleep and source
      // (a confirmed phone estimate stays one); changed times are manual.
      final kept = _keptAsleep;
      await sl<SleepService>().saveManualEntry(
        bed,
        wake,
        asleep: kept,
        source: kept != null && widget.initial?.source == SleepDataSource.phone
            ? SleepDataSource.phone
            : SleepDataSource.manual,
      );
    } catch (e) {
      debugPrint('Sleep entry not saved: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save your sleep. Try again.";
      });
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(_wakeDay, DateTime.now());
    final d = _duration;
    // Checked as the times change (a future wake-up shows at once), not
    // only on Save; Save stays off until the night can be saved.
    final (:bed, :wake) = _times;
    final ruleError = sleepEntryError(bed, wake, now: DateTime.now());
    final error = _error ?? ruleError;
    return TrackerSheet(
      metric: TrackerMetric.sleep,
      title: 'Log sleep',
      subtitle: 'Drag to set your night',
      // The clock sizes itself to the room left, so the sheet never needs
      // scrolling and the time cards never sit behind Save.
      scrollable: false,
      action: AppPrimaryButton(
        label: 'Save ${d.inHours}h ${d.inMinutes.remainder(60)}m',
        isLoading: _saving,
        enabled: ruleError == null,
        onTap: _save,
      ),
      // The clock fills the room left, so the sheet doesn't scroll. Only
      // where that room would make it smaller than readable (a short phone
      // at the largest text) does the sheet grow by the difference and
      // scroll, keeping the clock at its smallest usable size.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(
                    Icons.event_rounded,
                    size: AppDimens.iconXs,
                  ),
                  label: Text(
                    isToday
                        ? 'Last night'
                        : 'Night ending ${DateFormat('EEE d MMM').format(_wakeDay)}',
                  ),
                  onPressed: _pickDay,
                  // Tight so the clock keeps its room on short phones; the
                  // chip still has a full-height touch area at normal text.
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: AppDimens.space12),
              Flexible(
                child: CircularSleepClockPicker(
                  goal: Duration(
                    minutes:
                        widget.goalMinutes ??
                        sl<SleepService>().getGoalMinutes(),
                  ),
                  initialBedTime: _bed,
                  initialWakeTime: _wake,
                  // The same figure as Save: real elapsed time on the
                  // night's dates (right on daylight-saving nights), or a
                  // kept estimate's time asleep.
                  duration: _duration,
                  minDuration: minSleepEntry,
                  maxDuration: maxSleepEntry,
                  onClockSize: (size) {
                    if (!mounted) return;
                    final short = CircularSleepClockPicker.minClockSize - size;
                    if (short > 0.5) setState(() => _extraHeight += short);
                  },
                  onChanged: (b, w) => setState(() {
                    _bed = b;
                    _wake = w;
                    _error = null;
                  }),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppDimens.space8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
            ],
          );
          if (_extraHeight == 0) return content;
          return SingleChildScrollView(
            child: SizedBox(
              height: constraints.maxHeight + _extraHeight,
              child: content,
            ),
          );
        },
      ),
    );
  }
}
