import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'mood_widgets.dart';
import 'tracker_log_sheets.dart';

const _metric = TrackerMetric.mood;

/// Home card: tap a face to check in right here, optionally add what's
/// behind it. Celebrates each log, keeps a daily streak and a 7-day strip.
class StressCheckInCard extends StatelessWidget {
  const StressCheckInCard({super.key});

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<StressCheckInCubit>();
    await context.pushNamed(_metric.route);
    cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StressCheckInCubit, StressCheckInState>(
      builder: (context, state) {
        final cubit = context.read<StressCheckInCubit>();
        final today = state.today;
        final accent = stressColor(state.selectedLevel ?? today?.level ?? 3);
        return Stack(
          children: [
            TrackerCard(
              metric: _metric,
              status: today == null
                  ? TrackerStatus.notLogged
                  : TrackerStatus.done,
              statusLabel: today == null ? null : 'Checked in',
              onOpen: () => _open(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StreakPill(streak: state.streak, loggedToday: today != null),
                  const SizedBox(height: AppDimens.cardInnerGap),
                  AnimatedSwitcher(
                    duration: AppDurations.medium,
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.95, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    child: state.picking
                        ? _Picker(key: const ValueKey('picker'), state: state)
                        : _Logged(
                            key: const ValueKey('logged'),
                            checkIn: today!,
                            onEdit: cubit.edit,
                          ),
                  ),
                  const SizedBox(height: AppDimens.cardInnerGap),
                  Divider(
                    height: AppDimens.borderThin,
                    color: context.vColors.divider,
                  ),
                  const SizedBox(height: AppDimens.space12),
                  _MoodStrip(week: state.week),
                ],
              ),
            ),
            Positioned.fill(
              child: ConfettiBurst(trigger: state.celebrations, color: accent),
            ),
          ],
        );
      },
    );
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;
  final bool loggedToday;

  const _StreakPill({required this.streak, required this.loggedToday});

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    final color = active ? AppColors.streak : context.vColors.grayText!;
    final text = !active
        ? 'Check in today to start a streak'
        : loggedToday
        ? '$streak-day streak'
        : '$streak-day streak · check in to keep it';
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space10,
          vertical: AppDimens.space4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppDimens.tintAlpha),
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.local_fire_department_rounded
                  : Icons.local_fire_department_outlined,
              size: AppDimens.iconXs,
              color: color,
            ),
            const SizedBox(width: AppDimens.space4),
            Text(
              text,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  final StressCheckInState state;

  const _Picker({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StressCheckInCubit>();
    final level = state.selectedLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoodLevelPicker(selected: level, onSelected: cubit.selectLevel),
        AnimatedSize(
          duration: AppDurations.slow,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: level == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppDimens.cardInnerGap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "What's on your mind? (optional)",
                        style: context.text.bodySmall?.copyWith(
                          color: context.vColors.grayText,
                        ),
                      ),
                      const SizedBox(height: AppDimens.space8),
                      StressTagPicker(
                        selected: state.selectedTags,
                        onToggle: cubit.toggleTag,
                      ),
                      const SizedBox(height: AppDimens.cardInnerGap),
                      Row(
                        children: [
                          if (state.editing) ...[
                            Expanded(
                              child: AppSecondaryButton(
                                label: 'Cancel',
                                onTap: cubit.cancelEdit,
                              ),
                            ),
                            const SizedBox(width: AppDimens.space12),
                          ],
                          Expanded(
                            child: AppPrimaryButton(
                              label: state.editing ? 'Update' : 'Check in',
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                cubit.submit();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Logged extends StatelessWidget {
  final StressCheckIn checkIn;
  final VoidCallback onEdit;

  const _Logged({super.key, required this.checkIn, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final color = stressColor(checkIn.level);
    final message = switch (checkIn.level) {
      1 || 2 => 'Nice — keep that calm going.',
      3 => 'Steady day. A short walk can lift it.',
      _ => 'Tough one. Try a 2-minute breathing break.',
    };
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: AppDurations.bounce,
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: AppDimens.moodFaceBox,
            height: AppDimens.moodFaceBox,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: AppDimens.tintBorderAlpha),
            ),
            child: Icon(
              moodIcon(checkIn.level),
              size: AppDimens.moodFaceSize,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feeling ${checkIn.label.toLowerCase()} today',
                style: context.text.titleSmall?.copyWith(color: color),
              ),
              const SizedBox(height: AppDimens.space2),
              Text(
                checkIn.tags.isEmpty
                    ? message
                    : checkIn.tags.map((t) => t.label).join(' · '),
                style: context.text.bodySmall?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: SvgPicture.asset(
            'assets/icons/edit.svg',
            width: AppDimens.iconSm,
            height: AppDimens.iconSm,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary,
              BlendMode.srcIn,
            ),
          ),
          label: const Text('Edit'),
        ),
      ],
    );
  }
}

/// Last 7 days as mood icons (empty ring = no check-in), today emphasised.
class _MoodStrip extends StatelessWidget {
  final List<StressCheckIn?> week;

  const _MoodStrip({required this.week});

  @override
  Widget build(BuildContext context) {
    final days = lastNDays(7);
    final v = context.vColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < days.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                i < week.length && week[i] != null
                    ? moodIcon(week[i]!.level)
                    : Icons.radio_button_unchecked_rounded,
                size: AppDimens.iconMd,
                color: i < week.length && week[i] != null
                    ? stressColor(week[i]!.level)
                    : v.track,
              ),
              const SizedBox(height: AppDimens.space4),
              Text(
                DateFormat('E').format(days[i]).substring(0, 1),
                style: context.text.labelSmall?.copyWith(
                  color: i == days.length - 1
                      ? context.colors.onSurface
                      : v.grayText,
                  fontWeight: i == days.length - 1 ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
