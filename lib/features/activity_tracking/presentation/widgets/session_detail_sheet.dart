import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// Shows full stats for one session plus editable tag/note fields.
/// Call via [showSessionDetailSheet]; the returned future resolves with
/// (tag, note) if the user saved changes, or null if they dismissed it.
Future<(String?, String?)?> showSessionDetailSheet(
    BuildContext context, {
      required HistoryEntry entry,
    }) {
  final theme = Theme.of(context);
  return showModalBottomSheet<(String?, String?)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _SessionDetailSheet(entry: entry),
  );
}

class _SessionDetailSheet extends StatefulWidget {
  final HistoryEntry entry;

  const _SessionDetailSheet({required this.entry});

  @override
  State<_SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends State<_SessionDetailSheet> {
  late String _tag;
  late String _note;

  @override
  void initState() {
    super.initState();
    _tag = widget.entry.annotation?.tag ?? '';
    _note = widget.entry.annotation?.note ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();
    final session = widget.entry.session;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(activityTypeIcon(session.activityType), color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.activityType.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatShortDate(session.startTime)} · ${formatTimeOfDay(session.startTime)}',
                  style: TextStyle(color: customColors?.grayText ?? const Color(0xFF9A9A9A), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _DetailStat(label: 'Distance', value: '${formatDistanceKm(session.totalDistanceMeters)} km'),
                _DetailStat(
                  label: 'Duration',
                  value: formatDuration(Duration(seconds: session.totalDurationSeconds)),
                ),
                _DetailStat(label: 'Pace', value: '${formatPace(session.avgPaceSecondsPerKm)} /km'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _DetailStat(label: 'Calories', value: '${session.calories} cal'),
                _DetailStat(
                  label: 'Steps',
                  value: session.stepCountReliable ? '${session.steps}' : '${session.steps}*',
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
            if (session.targetType != null && session.targetValue != null && session.targetValue! > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: session.targetAchieved
                      ? colors.primary.withOpacity(0.12)
                      : colors.outline.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: session.targetAchieved
                        ? colors.primary.withOpacity(0.3)
                        : colors.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 20,
                      color: session.targetAchieved
                          ? colors.primary
                          : customColors?.grayText ?? const Color(0xFFFF9800),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target: ${session.targetType == 'distance' ? '${session.targetValue!.toStringAsFixed(1)} km' : '${session.targetValue!.toStringAsFixed(0)} kcal'}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            session.targetAchieved ? 'Achieved ✓' : 'Not achieved',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: session.targetAchieved
                                  ? colors.primary
                                  : customColors?.grayText ?? const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      session.targetAchieved
                          ? Icons.check_circle_rounded
                          : Icons.cancel_outlined,
                      color: session.targetAchieved
                          ? colors.primary
                          : customColors?.grayText ?? const Color(0xFFFF9800),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ],
            if (!session.stepCountReliable) ...[
              const SizedBox(height: 4),
              Text(
                '*Step count may be inaccurate for this session.',
                style: TextStyle(fontSize: 11, color: customColors?.grayText ?? const Color(0xFF9A9A9A)),
              ),
            ],
            const SizedBox(height: 20),
            AuthTextField(
              label: 'TAG',
              value: _tag,
              onChange: (val) => setState(() => _tag = val),
              placeholder: 'e.g. Morning run, Race day, Recovery',
              reserveErrorSpace: false,
              singleLine: true,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'NOTE',
              value: _note,
              onChange: (val) => setState(() => _note = val),
              placeholder: 'How did it feel?',
              reserveErrorSpace: false,
              singleLine: false,
            ),
            const SizedBox(height: 24),
            PrimaryAuthButton(
              label: 'Save',
              isLoading: false,
              onTap: () {
                Navigator.of(context).pop((
                  _tag.trim().isEmpty ? null : _tag.trim(),
                  _note.trim().isEmpty ? null : _note.trim(),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: customColors?.grayText ?? const Color(0xFF9A9A9A)),
          ),
        ],
      ),
    );
  }
}