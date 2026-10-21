import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';

/// What every onboarding step's state offers the flow: [submit] checks
/// and saves the step's answers when the user taps Continue, and returns
/// false (showing why) to stay on the step.
mixin OnboardingStepState<T extends StatefulWidget> on State<T> {
  Future<bool> submit();
}

/// Fades and lifts [child] in when its step appears. [index] places it in
/// a short cascade: the title first, then the subtitle, then each option.
/// Shown at once when the system asks for reduced motion.
class OnboardingReveal extends StatefulWidget {
  final int index;
  final Widget child;

  const OnboardingReveal({super.key, required this.index, required this.child});

  @override
  State<OnboardingReveal> createState() => _OnboardingRevealState();
}

class _OnboardingRevealState extends State<OnboardingReveal>
    with SingleTickerProviderStateMixin {
  static const _stagger = Duration(milliseconds: 45);

  /// Items further down start with the last one, so a long list doesn't
  /// keep the bottom of the page waiting.
  static const _maxDelayed = 8;

  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final delay = _stagger * math.min(widget.index, _maxDelayed);
    final total = delay + AppDurations.slow;
    _controller = AnimationController(vsync: this, duration: total);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _progress.value) * AppDimens.space16),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Segmented progress: one bar per step, filled up to [done]. A newly
/// reached segment sweeps in from the start.
class OnboardingProgress extends StatelessWidget {
  final int done;
  final int count;

  const OnboardingProgress({
    super.key,
    required this.done,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $done of $count',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: AppDimens.space4),
              Expanded(child: _ProgressSegment(filled: i < done)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  final bool filled;

  const _ProgressSegment({required this.filled});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: SizedBox(
        height: AppDimens.space6,
        child: ColoredBox(
          color: context.vColors.track!,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: filled ? 1 : 0),
            duration: AppDurations.slow,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value,
              heightFactor: 1,
              child: ColoredBox(color: context.colors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top of a step: "STEP 2 OF 7", the title and a grey subtitle,
/// revealed one after the other.
class OnboardingStepIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  const OnboardingStepIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingReveal(
          index: 0,
          child: AppCaption(eyebrow, color: context.vColors.accentText),
        ),
        const SizedBox(height: AppDimens.space8),
        OnboardingReveal(
          index: 1,
          child: Semantics(
            header: true,
            child: Text(title, style: context.text.headlineLarge),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimens.space8),
          OnboardingReveal(
            index: 2,
            child: Text(
              subtitle!,
              style: context.text.bodyLarge?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A small heading inside a step ("Target weight", "Weekly pace").
class OnboardingSectionLabel extends StatelessWidget {
  final String text;

  const OnboardingSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space12),
      child: Text(text, style: context.text.titleSmall),
    );
  }
}

/// One answer of a single-choice question: glass card with an icon
/// badge, title and grey subtitle, and a round check that fills in when
/// chosen. It presses in slightly under the finger. Picks something, so
/// no chevron.
class OnboardingChoiceTile extends StatefulWidget {
  final String title;
  final String? subtitle;

  /// Glyph inside the badge (an [Icon], or an SVG coloured with
  /// [AppIconBadge.glyphColor]).
  final Widget? icon;
  final bool selected;
  final VoidCallback onTap;

  const OnboardingChoiceTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  @override
  State<OnboardingChoiceTile> createState() => _OnboardingChoiceTileState();
}

class _OnboardingChoiceTileState extends State<OnboardingChoiceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    final selected = widget.selected;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? v.primaryFill : v.glassFill,
            borderRadius: radius,
            border: Border.all(
              color: selected ? v.primaryBorder! : v.glassBorder!,
              width: AppDimens.borderThin,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onTap();
              },
              onHighlightChanged: (down) => setState(() => _pressed = down),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.space16),
                child: Row(
                  children: [
                    if (widget.icon case final icon?) ...[
                      AppIconBadge(icon: icon),
                      const SizedBox(width: AppDimens.space12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: context.text.titleSmall),
                          if (widget.subtitle case final subtitle?) ...[
                            const SizedBox(height: AppDimens.space2),
                            Text(
                              subtitle,
                              style: context.text.bodyMedium?.copyWith(
                                color: v.grayText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.space12),
                    OnboardingSelectMark(selected: selected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round check: an empty ring that fills with the brand colour and pops
/// a tick in when [selected].
class OnboardingSelectMark extends StatelessWidget {
  final bool selected;

  const OnboardingSelectMark({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      width: AppDimens.iconLg,
      height: AppDimens.iconLg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.primary : colors.primary.withValues(alpha: 0),
        border: Border.all(
          color: selected ? colors.primary : context.vColors.grayText!,
          width: AppDimens.borderThick,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: AppDurations.bounce,
        curve: Curves.easeOutBack,
        child: Icon(
          Icons.check_rounded,
          size: AppDimens.iconXs,
          color: colors.onPrimary,
        ),
      ),
    );
  }
}

/// A big measured figure ("170 cm", "5 ft 7 in"): numbers in the large
/// metric style, units small and grey, with an optional [caption] under it.
class OnboardingReadout extends StatelessWidget {
  /// Number / unit pairs, e.g. `[('5', 'ft'), ('7', 'in')]`.
  final List<(String, String)> parts;
  final String? caption;
  final Color? captionColor;

  const OnboardingReadout({
    super.key,
    required this.parts,
    this.caption,
    this.captionColor,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final number = AppTextStyles.metricLarge.copyWith(
      color: context.colors.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final unit = context.text.titleSmall?.copyWith(color: grey);
    final spoken = parts.map((p) => '${p.$1} ${p.$2}').join(' ');

    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                TextSpan(text: i == 0 ? parts[i].$1 : ' ${parts[i].$1}'),
                TextSpan(text: ' ${parts[i].$2}', style: unit),
              ],
            ],
            style: number,
          ),
          textAlign: TextAlign.center,
          semanticsLabel: spoken,
        ),
        if (caption != null) ...[
          const SizedBox(height: AppDimens.space4),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: captionColor ?? grey,
            ),
          ),
        ],
      ],
    );
  }
}

/// Red line under a control that slides open when there's a problem.
class OnboardingErrorText extends StatelessWidget {
  final String? message;
  final TextAlign textAlign;

  const OnboardingErrorText(
    this.message, {
    super.key,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return AnimatedSize(
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppDimens.space8),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  message,
                  textAlign: textAlign,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ),
            ),
    );
  }
}
