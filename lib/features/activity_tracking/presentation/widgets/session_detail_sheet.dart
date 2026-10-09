import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_target_result.dart';

/// Shows full stats for one session plus editable tag/note fields.
/// Call via [showSessionDetailSheet]; the returned future resolves with
/// (tag, note) if the user saved changes, or null if they dismissed it.
Future<(String?, String?)?> showSessionDetailSheet(
  BuildContext context, {
  required HistoryEntry entry,
}) {
  return showAppBottomSheet<(String?, String?)>(
    context: context,
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
  late final TextEditingController _tag;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _tag = TextEditingController(text: widget.entry.annotation?.tag ?? '');
    _note = TextEditingController(text: widget.entry.annotation?.note ?? '');
  }

  @override
  void dispose() {
    _tag.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final session = widget.entry.session;
    final targetValue = session.targetValue;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        0,
        context.gutter,
        AppDimens.sectionGap + context.safePadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(icon: Icon(activityTypeIcon(session.activityType))),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.activityType.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      '${formatShortDate(session.startTime)} · ${formatTimeOfDay(session.startTime)}',
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space16),
          AppCard(
            padding: AppDimens.cardPaddingCompact,
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailStat(
                      label: 'Distance',
                      value:
                          '${formatDistanceKm(session.totalDistanceMeters)} km',
                    ),
                    _DetailStat(
                      label: 'Duration',
                      value: formatDuration(
                        Duration(seconds: session.totalDurationSeconds),
                      ),
                    ),
                    _DetailStat(
                      label: 'Pace',
                      value: '${formatPace(session.avgPaceSecondsPerKm)} /km',
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.space12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailStat(
                      label: 'Calories',
                      value: '${session.calories} cal',
                    ),
                    _DetailStat(
                      label: 'Steps',
                      value: session.stepCountReliable
                          ? '${session.steps}'
                          : '${session.steps}*',
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
          if (session.targetType != null &&
              targetValue != null &&
              targetValue > 0) ...[
            const SizedBox(height: AppDimens.cardGap),
            ActivityTargetResultCard(
              achieved: session.targetAchieved,
              title:
                  'Target: ${formatActivityTarget(session.targetType, targetValue)}',
              subtitle: session.targetAchieved ? 'Achieved' : 'Not achieved',
            ),
          ],
          if (!session.stepCountReliable) ...[
            const SizedBox(height: AppDimens.space8),
            Text(
              '*Step count may be inaccurate for this session.',
              style: context.text.bodySmall?.copyWith(color: v.grayText),
            ),
          ],
          const SizedBox(height: AppDimens.sectionGap),
          AppTextField(
            controller: _tag,
            label: 'Tag',
            hint: 'e.g. Morning run, Race day, Recovery',
            maxLength: SessionAnnotationLimits.tag,
            inputFormatters: InputFormatters.text(SessionAnnotationLimits.tag),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimens.space16),
          AppTextField(
            controller: _note,
            label: 'Note',
            hint: 'How did it feel?',
            multiline: true,
            minLines: 3,
            maxLines: 6,
            maxLength: SessionAnnotationLimits.note,
            showCounter: true,
            inputFormatters: InputFormatters.text(
              SessionAnnotationLimits.note,
              multiline: true,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppDimens.sectionGap),
          AppPrimaryButton(
            label: 'Save',
            onTap: () {
              Navigator.of(context).pop((
                sanitizeOptional(_tag.text, maxLength: SessionAnnotationLimits.tag),
                sanitizeOptional(
                  _note.text,
                  maxLength: SessionAnnotationLimits.note,
                  multiline: true,
                ),
              ));
            },
          ),
        ],
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
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: AppDimens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            Text(
              label,
              style: context.text.bodySmall?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
