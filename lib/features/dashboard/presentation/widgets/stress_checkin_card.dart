import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'dashboard_card_header.dart';
import 'mood_widgets.dart';
import 'trend_widgets.dart';

/// "How are you feeling?" — tap a face, add what's behind it, log it.
/// Celebrates each log, keeps a daily streak and a 7-day mood strip.
class StressCheckInCard extends StatelessWidget {
  const StressCheckInCard({super.key});

  Future<void> _openTrends(BuildContext context) async {
    final cubit = context.read<StressCheckInCubit>();
    await context.pushNamed('stress-trends');
    cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StressCheckInCubit, StressCheckInState>(
      builder: (context, state) {
        final cubit = context.read<StressCheckInCubit>();
        final accent = stressColor(state.selectedLevel ?? state.today?.level ?? 3);
        return AppCard(
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardCardHeader(
                    title: 'How are you feeling?',
                    icon: Icons.self_improvement_rounded,
                    badgeColor: AppColors.stressLevels.first,
                    trailing: CardLink(onTap: () => _openTrends(context)),
                  ),
                  const SizedBox(height: AppDimens.space8),
                  _StreakPill(streak: state.streak, loggedToday: state.today != null),
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
                            checkIn: state.today!,
                            onEdit: cubit.edit,
                          ),
                  ),
                  const SizedBox(height: AppDimens.cardInnerGap),
                  Divider(height: AppDimens.borderThin, color: context.vColors.divider),
                  const SizedBox(height: AppDimens.space12),
                  _MoodStrip(week: state.week),
                ],
              ),
              Positioned.fill(
                child: ConfettiBurst(trigger: state.celebrations, color: accent),
              ),
            ],
          ),
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
    final text = streak == 0
        ? 'Log today to start a streak'
        : loggedToday
            ? '$streak-day streak'
            : '$streak-day streak · log today to keep it';
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space10,
          vertical: AppDimens.space4,
        ),
        decoration: BoxDecoration(
          color: AppColors.streak.withValues(alpha: streak > 0 ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Text(
          '${streak > 0 ? '🔥 ' : ''}$text',
          style: context.text.labelSmall?.copyWith(
            color: streak > 0 ? AppColors.streak : context.vColors.grayText,
            fontWeight: FontWeight.w600,
          ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var l = 1; l <= 5; l++)
              AnimatedMoodFace(
                emoji: StressCheckIn.emojis[l - 1],
                label: StressCheckIn.labels[l - 1],
                color: stressColor(l),
                selected: level == l,
                onTap: () {
                  HapticFeedback.selectionClick();
                  cubit.selectLevel(l);
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
              color: level == null ? context.vColors.grayText : stressColor(level),
            ),
          ),
        ),
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
                        style: context.text.bodySmall
                            ?.copyWith(color: context.vColors.grayText),
                      ),
                      const SizedBox(height: AppDimens.space8),
                      Wrap(
                        spacing: AppDimens.space8,
                        runSpacing: AppDimens.space8,
                        children: [
                          for (final tag in StressTag.values)
                            FilterChip(
                              label: Text('${tag.emoji} ${tag.label}'),
                              selected: state.selectedTags.contains(tag),
                              showCheckmark: false,
                              onSelected: (_) => cubit.toggleTag(tag),
                            ),
                        ],
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
                              label: state.editing ? 'Update' : 'Log mood',
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
              color: color.withValues(alpha: 0.25),
            ),
            child: Text(
              checkIn.emoji,
              style: const TextStyle(fontSize: AppDimens.moodFaceSize),
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
                    : checkIn.tags.map((t) => '${t.emoji} ${t.label}').join('  '),
                style: context.text.bodySmall
                    ?.copyWith(color: context.vColors.grayText),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onEdit, child: const Text('Edit')),
      ],
    );
  }
}

/// Last 7 days as coloured dots (grey = no check-in), today emphasised.
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
              AnimatedContainer(
                duration: AppDurations.medium,
                width: AppDimens.moodStripDot,
                height: AppDimens.moodStripDot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < week.length && week[i] != null
                      ? stressColor(week[i]!.level)
                      : v.track,
                ),
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
