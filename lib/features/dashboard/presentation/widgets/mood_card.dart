import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'mood_widgets.dart';
import 'tracker_log_sheets.dart';

const _metric = TrackerMetric.mood;

/// Home tile: today's mood check-in, or a prompt to check in. Checking in
/// and editing open the mood sheet.
class MoodCard extends StatelessWidget {
  const MoodCard({super.key});

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<StressCheckInCubit>();
    await context.pushNamed(_metric.route);
    cubit.load();
  }

  Future<void> _log(BuildContext context) async {
    final cubit = context.read<StressCheckInCubit>();
    if (await showMoodLogSheet(context, initial: cubit.state.today)) {
      cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StressCheckInCubit, StressCheckInState>(
      builder: (context, state) {
        final today = state.today;
        return TrackerCard(
          metric: _metric,
          title: 'Mood',
          status: today == null ? TrackerStatus.notLogged : TrackerStatus.done,
          statusLabel: today == null ? null : 'Checked in',
          onOpen: () => _open(context),
          actions: [
            TrackerQuickAction(
              label: today == null ? _metric.logLabel : 'Edit',
              icon: today == null ? _metric.logIcon : Icons.edit_rounded,
              svgAsset: today == null
                  ? _metric.logIconAsset
                  : TrackerIcons.edit,
              color: _metric.color,
              filled: true,
              onTap: () => _log(context),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (today == null)
                TrackerPrompt(
                  title: 'How are you feeling?',
                  color: _metric.color,
                )
              else ...[
                // The face flows with the words, so a long mood ("Very
                // stressed") wraps at the same size as the other tiles'
                // figures instead of shrinking beside the icon.
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: AppDimens.space8,
                          ),
                          child: Icon(
                            moodIcon(today.level),
                            size: AppDimens.iconXl,
                            color: context.iconTint(stressColor(today.level)),
                          ),
                        ),
                      ),
                      TextSpan(text: today.label),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: today.label,
                  style: AppTextStyles.metric.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
