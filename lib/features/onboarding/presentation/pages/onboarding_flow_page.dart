import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/onboarding/data/starting_goals_writer.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/auth/presentation/widgets/animated_tick.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/features/onboarding/domain/onboarding_step.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/pages/activity_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/dietary_preference_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/goals.dart';
import 'package:vital_up/features/onboarding/presentation/pages/height_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/info_and_permission_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/personal_details_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/weight_page.dart';
import 'package:vital_up/features/onboarding/presentation/widgets/onboarding_widgets.dart';

/// The health onboarding: one page whose steps slide in and out (forward
/// to the left, back to the right) under a fixed header (back, segmented
/// progress, Skip) and a pinned Continue button, ending on a "You're all
/// set" screen. Each step's answers are saved when it's left with
/// Continue, and the step itself is saved so the flow resumes there.
class OnboardingFlowPage extends StatefulWidget {
  final OnboardingStep initialStep;

  const OnboardingFlowPage({
    super.key,
    this.initialStep = OnboardingStep.about,
  });

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  late OnboardingStep _step = widget.initialStep;

  /// Counts every change of screen: the switcher's key, so a step shown
  /// again (back, then forward) never shares a key with its outgoing copy.
  int _visit = 0;
  bool _forward = true;
  bool _working = false;
  bool _done = false;

  /// A fresh key for every visit, for the same reason as [_visit].
  GlobalKey<OnboardingStepState> _stepKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    context.read<OnboardingCubit>().setCurrentStep(_step.id);
  }

  void _show(OnboardingStep step, {required bool forward}) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = step;
      _forward = forward;
      _visit++;
      _stepKey = GlobalKey();
    });
    context.read<OnboardingCubit>().setCurrentStep(step.id);
  }

  Future<void> _continue() async {
    final state = _stepKey.currentState;
    if (_working || _done || state == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _working = true);
    var ok = false;
    try {
      ok = await state.submit();
    } catch (e) {
      debugPrint('Onboarding step not saved: $e');
    }
    if (!mounted) return;
    setState(() => _working = false);
    if (!ok) {
      HapticFeedback.mediumImpact();
      return;
    }
    final next = _step.next;
    if (next != null) {
      _show(next, forward: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _done = true;
      _forward = true;
      _visit++;
    });
  }

  void _skip() {
    final next = _step.next;
    if (_working || _done || next == null || !_step.skippable) return;
    _show(next, forward: true);
  }

  void _back() {
    final previous = _step.previous;
    if (_working || _done || previous == null) return;
    _show(previous, forward: false);
  }

  void _goHome() => context.goNamed('dashboard');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The first step is where the flow starts: back leaves the app as
      // before. Later steps go back a step instead of closing the flow.
      canPop: _step.isFirst && !_working && !_done,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_done) {
          _goHome();
        } else {
          _back();
        }
      },
      child: AppScaffold(
        scrollable: false,
        padBody: false,
        header: _FlowHeader(
          step: _step,
          done: _done,
          enabled: !_working,
          onBack: _back,
          onSkip: _skip,
        ),
        body: AnimatedSwitcher(
          duration: AppDurations.page,
          reverseDuration: AppDurations.pageReverse,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          transitionBuilder: _transition,
          child: KeyedSubtree(
            key: ValueKey(_visit),
            child: _done ? const _DoneView() : _stepView(),
          ),
        ),
        bottomBar: _done
            ? AppPrimaryButton(label: 'Go to Home', onTap: _goHome)
            : AppPrimaryButton(
                label: _step.isLast ? 'Finish' : 'Continue',
                isLoading: _working,
                showRightArrow: !_step.isLast,
                onTap: _continue,
              ),
      ),
    );
  }

  /// Shared-axis slide: the new screen comes in from the side it's
  /// heading to while the old one drifts off the other way and fades.
  Widget _transition(Widget child, Animation<double> animation) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0.5, 1, curve: Curves.easeIn),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: fade, child: child);
    }
    final incoming = child.key == ValueKey(_visit);
    final direction = _forward ? 1.0 : -1.0;
    final slide = CurvedAnimation(
      parent: animation,
      curve: Easing.emphasizedDecelerate,
      reverseCurve: Easing.emphasizedAccelerate.flipped,
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween(
          begin: Offset((incoming ? 0.18 : -0.18) * direction, 0),
          end: Offset.zero,
        ).animate(slide),
        child: child,
      ),
    );
  }

  Widget _stepView() {
    final (title, subtitle) = _copy(_step);
    final body = switch (_step) {
      OnboardingStep.about => PersonalDetailsStep(key: _stepKey),
      OnboardingStep.height => HeightStep(key: _stepKey),
      OnboardingStep.weight => WeightStep(key: _stepKey),
      OnboardingStep.diet => DietaryPreferenceStep(key: _stepKey),
      OnboardingStep.goal => GoalStep(key: _stepKey),
      OnboardingStep.activity => ActivityStep(key: _stepKey),
      OnboardingStep.privacy => PrivacyStep(key: _stepKey),
    };
    return _StepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingStepIntro(
            eyebrow: 'Step ${_step.number} of ${OnboardingStep.values.length}',
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: AppDimens.space24),
          body,
        ],
      ),
    );
  }

  static (String, String) _copy(OnboardingStep step) => switch (step) {
    OnboardingStep.about => (
      'About you',
      'A few basics to personalise your health insights.',
    ),
    OnboardingStep.height => (
      'How tall are you?',
      'Used for your BMI and energy needs.',
    ),
    OnboardingStep.weight => (
      'What do you weigh?',
      'Your starting point. Only you can see it.',
    ),
    OnboardingStep.diet => (
      'How do you eat?',
      'Meal ideas and diet plans will follow it.',
    ),
    OnboardingStep.goal => (
      "What's your goal?",
      'We use it to set your daily calories.',
    ),
    OnboardingStep.activity => (
      'How active are you?',
      'So your goals fit your day.',
    ),
    OnboardingStep.privacy => (
      'Your data, your call',
      'We only keep what VitalUp needs to help you.',
    ),
  };
}

/// One step's content, scrolling on its own (so a step always opens at
/// its top) within the 16dp gutter and the tablet width cap.
class _StepScroll extends StatelessWidget {
  final Widget child;

  const _StepScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ResponsiveCenter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            AppDimens.space16,
            context.gutter,
            AppDimens.sectionGap,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Back, the segmented progress and Skip. Back and Skip keep their room
/// when hidden, so the progress bar never jumps between steps.
class _FlowHeader extends StatelessWidget {
  final OnboardingStep step;
  final bool done;
  final bool enabled;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _FlowHeader({
    required this.step,
    required this.done,
    required this.enabled,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final count = OnboardingStep.values.length;
    final showBack = !done && !step.isFirst;
    final showSkip = !done && step.skippable;

    return Padding(
      padding: EdgeInsets.only(
        top: context.safePadding.top + AppDimens.space12,
        bottom: AppDimens.space4,
      ),
      child: ResponsiveCenter(
        child: Padding(
          padding: context.pagePadding,
          child: Row(
            children: [
              _Appear(
                visible: showBack,
                child: BackIcon(onClick: enabled ? onBack : () {}),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: OnboardingProgress(
                  done: done ? count : step.number,
                  count: count,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              _Appear(
                visible: showSkip,
                child: TextButton(
                  onPressed: enabled ? onSkip : null,
                  style: TextButton.styleFrom(
                    foregroundColor: context.vColors.grayText,
                    textStyle: context.text.titleSmall,
                    minimumSize: const Size(
                      AppDimens.backButtonSize,
                      AppDimens.backButtonSize,
                    ),
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades [child] in and out, keeping its size and taking it out of the
/// way of taps and screen readers while hidden.
class _Appear extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _Appear({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppDurations.medium,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(excluding: !visible, child: child),
      ),
    );
  }
}

/// The end of the flow: an animated tick, a welcome by first name and
/// the goals worked out from the answers (daily calories plus the
/// starting goals [StartingGoalsWriter] saved), with a link to adjust
/// them in My goals.
class _DoneView extends StatefulWidget {
  const _DoneView();

  @override
  State<_DoneView> createState() => _DoneViewState();
}

class _DoneViewState extends State<_DoneView> {
  Future<void> _adjust() async {
    await context.pushNamed('my-goals');
    // Shows what was changed there.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<OnboardingCubit>().state;
    final firstName = state.fullName.trim().split(RegExp(r'\s+')).first;
    final calories = int.tryParse(state.calorieGoal);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ResponsiveCenter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.gutter,
                vertical: AppDimens.sectionGap,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AnimatedTick(),
                  const SizedBox(height: AppDimens.space24),
                  OnboardingReveal(
                    index: 3,
                    child: Semantics(
                      header: true,
                      child: Text(
                        firstName.isEmpty
                            ? "You're all set"
                            : "You're all set, $firstName",
                        textAlign: TextAlign.center,
                        style: context.text.headlineLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.space8),
                  OnboardingReveal(
                    index: 4,
                    child: Text(
                      'We set your first goals from your answers. Change '
                      'them any time.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.sectionGap),
                  OnboardingReveal(
                    index: 5,
                    child: _GoalsCard(calories: calories, onAdjust: _adjust),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Static card: each goal as icon, name and target, with "Adjust" (a text
/// link to My goals) beside the title.
class _GoalsCard extends StatelessWidget {
  final int? calories;
  final VoidCallback onAdjust;

  const _GoalsCard({required this.calories, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final calories = this.calories;
    final activity = {
      for (final g in sl<ActivityGoalsRepository>().getGoals()) g.metric: g,
    };
    final steps = activity[GoalMetric.steps];
    final workouts = activity[GoalMetric.workouts];
    final count = NumberFormat.decimalPattern();
    String per(ActivityGoal g) =>
        g.period == GoalPeriod.daily ? 'a day' : 'a week';
    final water = sl<WaterIntakeService>().getDailyGoal()?.toDouble();
    final sleep = sl<SleepService>().getGoalMinutes()?.toDouble();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Your goals', style: context.text.titleSmall),
              ),
              CardLink(label: 'Adjust', onTap: onAdjust),
            ],
          ),
          if (calories != null)
            _GoalLine(
              badge: const TrackerBadge(
                TrackerMetric.nutrition,
                size: AppDimens.iconBadgeSmall,
              ),
              label: 'Calories',
              value: '${count.format(calories)} kcal a day',
            ),
          if (water != null)
            _GoalLine(
              badge: const TrackerBadge(
                TrackerMetric.water,
                size: AppDimens.iconBadgeSmall,
              ),
              label: 'Water',
              value: '${formatWaterGoal(water)} a day',
            ),
          if (steps != null)
            _GoalLine(
              badge: _activityBadge(context, GoalMetric.steps),
              label: 'Steps',
              value: '${count.format(steps.target.round())} ${per(steps)}',
            ),
          if (workouts != null)
            _GoalLine(
              badge: _activityBadge(context, GoalMetric.workouts),
              label: 'Workouts',
              value: '${workouts.target.round()} ${per(workouts)}',
            ),
          if (sleep != null)
            _GoalLine(
              badge: const TrackerBadge(
                TrackerMetric.sleep,
                size: AppDimens.iconBadgeSmall,
              ),
              label: 'Sleep',
              value: '${formatMinutesGoal(sleep)} a night',
            ),
        ],
      ),
    );
  }

  static Widget _activityBadge(BuildContext context, GoalMetric metric) {
    final color = metric.color;
    return AppIconBadge(
      size: AppDimens.iconBadgeSmall,
      color: color,
      icon: GoalMetricIcon(
        metric,
        size: AppDimens.iconXs,
        color: AppIconBadge.glyphColor(context, color),
      ),
    );
  }
}

/// One goal: badge, name, and the target at the end of the line (under
/// the name when both don't fit).
class _GoalLine extends StatelessWidget {
  final Widget badge;
  final String label;
  final String value;

  const _GoalLine({
    required this.badge,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.space12),
      child: Row(
        children: [
          badge,
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space2,
              children: [
                Text(label, style: context.text.bodyLarge),
                Text(
                  value,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
