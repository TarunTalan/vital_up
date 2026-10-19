import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_summary.dart';

/// One session's [ActivitySummary] (the same as after a workout) plus
/// editable tag/note fields.
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
    final session = widget.entry.session;

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
          ActivitySummary(session: session),
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
                sanitizeOptional(
                  _tag.text,
                  maxLength: SessionAnnotationLimits.tag,
                ),
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
