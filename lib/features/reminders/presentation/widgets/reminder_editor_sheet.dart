import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/presentation/widgets/reminder_style.dart';

/// What the editor sheet closed with.
sealed class ReminderEdit {
  const ReminderEdit();
}

class ReminderSaved extends ReminderEdit {
  final Reminder reminder;
  const ReminderSaved(this.reminder);
}

class ReminderDeleted extends ReminderEdit {
  const ReminderDeleted();
}

/// Opens the editor for [reminder]; [isNew] hides Delete and turns the
/// reminder on when saved.
Future<ReminderEdit?> showReminderEditor(
  BuildContext context, {
  required Reminder reminder,
  bool isNew = false,
}) => showAppBottomSheet<ReminderEdit>(
  context: context,
  builder: (_) => ReminderEditorSheet(reminder: reminder, isNew: isNew),
);

class ReminderEditorSheet extends StatefulWidget {
  final Reminder reminder;
  final bool isNew;

  const ReminderEditorSheet({
    super.key,
    required this.reminder,
    this.isNew = false,
  });

  @override
  State<ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<ReminderEditorSheet> {
  static const _maxTimes = 6;
  static const _intervals = [30, 60, 90, 120, 180, 240];

  late final _title = TextEditingController(text: widget.reminder.title);
  late List<ReminderTime> _times = [...widget.reminder.times];
  late Set<int> _weekdays = {...widget.reminder.weekdays};
  late String? _route = widget.reminder.route;
  late int? _interval = widget.reminder.intervalMinutes;
  late ReminderTime? _windowStart = widget.reminder.windowStart;
  late ReminderTime? _windowEnd = widget.reminder.windowEnd;
  String? _error;

  bool get _isCustom => widget.reminder.kind == ReminderKind.custom;
  bool get _isInterval => widget.reminder.isInterval;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<ReminderTime?> _pick(ReminderTime initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    return picked == null ? null : ReminderTime(picked.hour, picked.minute);
  }

  void _save() {
    final title = _title.text.trim();
    final String? error;
    if (_isCustom && title.isEmpty) {
      error = 'Give your reminder a name.';
    } else if (_weekdays.isEmpty) {
      error = 'Pick at least one day.';
    } else if (_isInterval && _windowEnd!.compareTo(_windowStart!) <= 0) {
      error = 'The end time must be after the start time.';
    } else if (!_isInterval && _times.isEmpty) {
      error = 'Add at least one time.';
    } else {
      error = null;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final base = widget.reminder;
    Navigator.pop(
      context,
      ReminderSaved(
        base.copyWith(
          title: _isCustom ? title : null,
          times: _times,
          weekdays: _weekdays,
          route: () => _route,
          intervalMinutes: _interval,
          windowStart: _windowStart,
          windowEnd: _windowEnd,
          enabled: widget.isNew ? true : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
                  child: Text(
                    widget.isNew
                        ? 'New reminder'
                        : (_isCustom ? 'Edit reminder' : widget.reminder.title),
                    style: context.text.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
            Divider(height: AppDimens.borderThin, color: v.divider),
            const SizedBox(height: AppDimens.sectionGap),
            if (_isCustom) ...[
              AppTextField(
                label: 'Name',
                controller: _title,
                hint: 'e.g. Take vitamins',
                textCapitalization: TextCapitalization.sentences,
                autofocus: widget.isNew,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: AppDimens.space16),
              AppDropdownField<String?>(
                label: 'Opens',
                value: _route,
                items: [for (final t in reminderTargets) t.$2],
                itemLabel: (route) =>
                    reminderTargets.firstWhere((t) => t.$2 == route).$1,
                onChanged: (route) => setState(() => _route = route),
              ),
              const SizedBox(height: AppDimens.space16),
            ],
            if (_isInterval)
              ..._buildIntervalFields()
            else
              ..._buildTimeFields(),
            const SizedBox(height: AppDimens.space16),
            Text('Repeat on', style: context.text.titleSmall),
            const SizedBox(height: AppDimens.space8),
            _WeekdayPicker(
              selected: _weekdays,
              onChanged: (days) => setState(() {
                _weekdays = days;
                _error = null;
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.space12),
              Text(
                _error!,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ],
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
                  child: AppPrimaryButton(label: 'Save', onTap: _save),
                ),
              ],
            ),
            if (_isCustom && !widget.isNew) ...[
              const SizedBox(height: AppDimens.space8),
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, const ReminderDeleted()),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: context.colors.error,
                ),
                label: Text(
                  'Delete reminder',
                  style: context.text.labelLarge?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildIntervalFields() => [
    AppDropdownField<int>(
      label: 'How often',
      value: _interval,
      items: _intervals,
      itemLabel: intervalLabel,
      onChanged: (m) => setState(() => _interval = m ?? _interval),
    ),
    const SizedBox(height: AppDimens.space16),
    Row(
      children: [
        Expanded(
          child: AppDisplayField(
            label: 'From',
            value: _windowStart!.label,
            trailingIcon: Icons.schedule_rounded,
            onTap: () async {
              final t = await _pick(_windowStart!);
              if (t != null) setState(() => _windowStart = t);
            },
          ),
        ),
        const SizedBox(width: AppDimens.space16),
        Expanded(
          child: AppDisplayField(
            label: 'Until',
            value: _windowEnd!.label,
            trailingIcon: Icons.schedule_rounded,
            onTap: () async {
              final t = await _pick(_windowEnd!);
              if (t != null) setState(() => _windowEnd = t);
            },
          ),
        ),
      ],
    ),
  ];

  List<Widget> _buildTimeFields() => [
    for (var i = 0; i < _times.length; i++) ...[
      if (i > 0) const SizedBox(height: AppDimens.space8),
      Row(
        children: [
          Expanded(
            child: AppDisplayField(
              label: i == 0 ? 'Time' : null,
              value: _times[i].label,
              trailingIcon: Icons.schedule_rounded,
              onTap: () async {
                final t = await _pick(_times[i]);
                if (t != null) {
                  setState(() => _times = [..._times]..[i] = t);
                }
              },
            ),
          ),
          if (_times.length > 1)
            IconButton(
              tooltip: 'Remove time',
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                color: context.vColors.grayText,
              ),
              onPressed: () =>
                  setState(() => _times = [..._times]..removeAt(i)),
            ),
        ],
      ),
    ],
    if (_times.length < _maxTimes)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () async {
            final last = _times.isEmpty
                ? const ReminderTime(9, 0)
                : _times.last;
            final t = await _pick(last);
            if (t != null) setState(() => _times = [..._times, t]);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add time'),
        ),
      ),
  ];
}

/// Seven round day toggles, Monday first.
class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _WeekdayPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final primary = context.colors.primary;
    return Row(
      children: [
        for (var day = 1; day <= 7; day++)
          Expanded(
            child: Center(
              child: Semantics(
                button: true,
                selected: selected.contains(day),
                child: Material(
                  color: selected.contains(day) ? primary : v.glassFill,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: selected.contains(day) ? primary : v.glassBorder!,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(
                      selected.contains(day)
                          ? ({...selected}..remove(day))
                          : {...selected, day},
                    ),
                    child: SizedBox.square(
                      dimension: AppDimens.space40,
                      child: Center(
                        child: Text(
                          weekdayLetter(day),
                          style: context.text.labelLarge?.copyWith(
                            color: selected.contains(day)
                                ? v.buttonText
                                : v.grayText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
