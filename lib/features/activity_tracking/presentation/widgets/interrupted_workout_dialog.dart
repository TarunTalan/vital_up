import 'package:flutter/material.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_checkpoint.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';

enum InterruptedWorkoutChoice { resume, save, discard }

/// Asks what to do with a workout the app was closed in the middle of.
/// Pops with an [InterruptedWorkoutChoice], or null when dismissed (it is
/// offered again on the next visit).
class InterruptedWorkoutDialog extends StatelessWidget {
  final ActivitySession session;
  final DistanceUnit unit;

  const InterruptedWorkoutDialog({
    super.key,
    required this.session,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activity = session.activityType.label.toLowerCase();
    final elapsed = WorkoutCheckpoint.restoredElapsed(session);
    final summary =
        '${formatDistance(session.totalDistanceMeters, unit: unit)} '
        '${unit.label} in ${formatDuration(elapsed)} so far.';

    void choose(InterruptedWorkoutChoice choice) =>
        Navigator.of(context).pop(choice);

    return AlertDialog(
      title: const Text('Continue your workout?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your $activity from ${formatTimeOfDay(session.startTime)} '
            'stopped when the app closed. $summary',
            style: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space24),
          AppPrimaryButton(
            label: 'Resume workout',
            onTap: () => choose(InterruptedWorkoutChoice.resume),
          ),
          const SizedBox(height: AppDimens.space12),
          AppSecondaryButton(
            label: 'Save and finish',
            onTap: () => choose(InterruptedWorkoutChoice.save),
          ),
          const SizedBox(height: AppDimens.space8),
          Center(
            child: TextButton(
              onPressed: () => choose(InterruptedWorkoutChoice.discard),
              child: Text(
                'Discard workout',
                style: TextStyle(color: colors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
