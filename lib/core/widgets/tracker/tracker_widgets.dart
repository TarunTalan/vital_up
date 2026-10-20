import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/measured_layout_builder.dart';
import 'package:vital_up/core/widgets/adaptive_row.dart';
import 'package:vital_up/core/utils/responsive.dart';

/// The metric's SVG tinted with its accent (or [color]).
class TrackerIcon extends StatelessWidget {
  final TrackerMetric metric;
  final double size;
  final Color? color;

  const TrackerIcon(
    this.metric, {
    super.key,
    this.size = AppDimens.iconMd,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      metric.iconAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? context.iconTint(metric.color),
        BlendMode.srcIn,
      ),
    );
  }
}

/// Accent-tinted circle with the metric icon — the metric's "avatar".
class TrackerBadge extends StatelessWidget {
  final TrackerMetric metric;
  final double size;

  const TrackerBadge(this.metric, {super.key, this.size = AppDimens.iconBadge});

  @override
  Widget build(BuildContext context) {
    return AppIconBadge(
      color: metric.color,
      size: size,
      icon: TrackerIcon(
        metric,
        size: size / 2,
        color: AppIconBadge.glyphColor(context, metric.color),
      ),
    );
  }
}

/// Header row shared by every tracker card: badge, title, status chip and a
/// chevron that signals the whole card opens the detail page.
class TrackerCardHeader extends StatelessWidget {
  final TrackerMetric metric;
  final String? title;
  final TrackerStatus? status;
  final String? statusLabel;
  final Color? statusColor;
  final bool showChevron;

  const TrackerCardHeader({
    super.key,
    required this.metric,
    this.title,
    this.status,
    this.statusLabel,
    this.statusColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side-by-side Home tiles always use the compact header (no chip),
        // so a pair's figures line up on every device, tablets included.
        final isCompact =
            constraints.maxWidth < 200 || _TileScope.inTile(context);
        final titleText = title ?? metric.label;
        final titleStyle = context.text.titleSmall?.copyWith(
          color: context.colors.onSurface,
        );
        final badge = isCompact
            ? AppDimens.iconBadgeSmall
            : AppDimens.iconBadge;
        final gap = isCompact ? AppDimens.space8 : AppDimens.space12;
        final chip = status != null && !isCompact
            ? TrackerStatusChip(status!, label: statusLabel, color: statusColor)
            : null;
        final chevron = showChevron && !isCompact;
        // The chip moves under the title when both don't fit one row
        // (large text), so the title stays whole.
        var chipBelow = false;
        if (chip != null) {
          final chipWidth =
              _textWidth(
                context,
                statusLabel ?? status!.label,
                context.text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ) +
              AppDimens.iconXs +
              AppDimens.space4 +
              AppDimens.space8 * 2 +
              AppDimens.borderThin * 2;
          final titleRoom =
              constraints.maxWidth -
              badge -
              gap -
              AppDimens.space8 -
              chipWidth -
              (chevron ? AppDimens.space4 + AppDimens.iconMd : 0);
          chipBelow = !FitText.fits(
            context,
            TextSpan(text: titleText, style: titleStyle),
            titleRoom,
          );
        }
        final titleWidget = FitText(titleText, style: titleStyle);
        // Tiles have no chip: a met goal shows as a check on the badge's
        // corner, which takes no room from the title, so it shows on
        // every phone and text size.
        final doneMark = chip == null && status == TrackerStatus.done;
        // Half-width tiles get a smaller badge and gap so the title fits
        // whole at its normal size.
        return Row(
          children: [
            Semantics(
              label: doneMark ? (statusLabel ?? status!.label) : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  TrackerBadge(metric, size: badge),
                  if (doneMark)
                    Positioned(
                      right: -AppDimens.space4,
                      bottom: -AppDimens.space4,
                      child: _DoneMark(color: statusColor),
                    ),
                ],
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: chipBelow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: AppDimens.space4),
                        chip!,
                      ],
                    )
                  : titleWidget,
            ),
            if (chip != null && !chipBelow) ...[
              const SizedBox(width: AppDimens.space8),
              chip,
            ],
            if (chevron) ...[
              const SizedBox(width: AppDimens.space4),
              Icon(
                Icons.chevron_right_rounded,
                size: AppDimens.iconMd,
                color: context.vColors.grayText,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Green check on a tile badge's corner: the tracker's goal is met (or
/// today is logged). Ringed in the card colour so it reads on the badge.
class _DoneMark extends StatelessWidget {
  final Color? color;

  const _DoneMark({this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.isDark
            ? AppColors.cardBackdropDark
            : AppColors.cardBackdropLight,
      ),
      child: Icon(
        Icons.check_circle_rounded,
        size: AppDimens.iconXs,
        color: context.iconTint(color ?? context.vColors.success!),
      ),
    );
  }
}

/// Width of [text] in [style] at the current text size.
double _textWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Line height of [text] in [style] at the current text size.
double _textHeight(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Home card shell for a tracker: tapping anywhere opens its detail page;
/// [actions] (quick logs) sit at the bottom. In a fixed-height slot (Home
/// tile pairs) [child] is centred in the room between header and actions;
/// otherwise the card takes its content's height, with no empty bands. A met goal mutes the card a
/// little, adds a check to the header and turns filled actions into
/// outlined ones, so only unfinished trackers carry a call to action.
class TrackerCard extends StatelessWidget {
  final TrackerMetric metric;
  final TrackerStatus? status;
  final String? statusLabel;
  final Color? statusColor;
  final String? title;
  final VoidCallback? onOpen;
  final Widget? child;
  final List<Widget> actions;

  const TrackerCard({
    super.key,
    required this.metric,
    this.status,
    this.statusLabel,
    this.statusColor,
    this.title,
    this.onOpen,
    this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final done = status == TrackerStatus.done;
    return Semantics(
      container: true,
      label:
          '${title ?? metric.label}'
          '${status == null ? '' : ', ${statusLabel ?? status!.label}'}',
      child: AnimatedOpacity(
        duration: AppDurations.medium,
        opacity: done ? AppDimens.completedOpacity : 1,
        child: AppCard(
          width: double.infinity,
          onTap: onOpen,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrackerCardHeader(
                  metric: metric,
                  title: title,
                  status: status,
                  statusLabel: statusLabel,
                  statusColor: statusColor,
                  showChevron: onOpen != null,
                ),
                if (child != null) ...[
                  const SizedBox(height: AppDimens.cardInnerGap),
                  if (constraints.hasBoundedHeight)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [child!],
                      ),
                    )
                  else
                    child!,
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.cardInnerGap),
                  _GoalMetScope(
                    goalMet: done,
                    child: TrackerActionRow(actions: actions),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells a [TrackerCard]'s actions that its goal is met.
class _GoalMetScope extends InheritedWidget {
  final bool goalMet;

  const _GoalMetScope({required this.goalMet, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GoalMetScope>()?.goalMet ??
      false;

  @override
  bool updateShouldNotify(_GoalMetScope old) => old.goalMet != goalMet;
}

/// Lays quick actions out in equal-width columns; when a label wouldn't
/// show whole in its column (narrow phone, large text) they stack full
/// width instead.
class TrackerActionRow extends StatelessWidget {
  final List<Widget> actions;

  const TrackerActionRow({super.key, required this.actions});

  static const double _gap = AppDimens.space8;

  @override
  Widget build(BuildContext context) {
    if (actions.length < 2) return _row();
    return LayoutBuilder(
      builder: (context, constraints) {
        final column =
            (constraints.maxWidth - _gap * (actions.length - 1)) /
            actions.length;
        final fits = actions.every(
          (a) =>
              a is! TrackerQuickAction ||
              TrackerQuickAction.widthFor(context, a.label) <= column,
        );
        return fits ? _row() : _column();
      },
    );
  }

  Widget _column() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(height: _gap),
        actions[i],
      ],
    ],
  );

  Widget _row() => Row(
    children: [
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(width: _gap),
        Expanded(child: actions[i]),
      ],
    ],
  );
}

/// Compact tinted button for one-tap logging on cards and sheets
/// ("+250 ml", "Log sleep"). [filled] marks the card's main action; on a
/// card whose goal is met it shows outlined instead. Every action uses the
/// brand colour so buttons read the same on every card; the metric's
/// accent stays on its icon, figures and bars.
class TrackerQuickAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? svgAsset;

  /// The metric's accent. Kept for callers; actions draw in the brand
  /// colour (see above).
  final Color color;
  final VoidCallback? onTap;
  final bool filled;
  final String? semanticLabel;

  const TrackerQuickAction({
    super.key,
    required this.label,
    this.icon,
    this.svgAsset,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.semanticLabel,
  });

  /// Width that shows [label] whole at its full size, with the icon
  /// (or without it, [withIcon] false).
  static double widthFor(
    BuildContext context,
    String label, {
    bool withIcon = true,
  }) =>
      _textWidth(
        context,
        label,
        context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ) +
      (withIcon ? AppDimens.iconSm + AppDimens.space6 : 0) +
      AppDimens.space8 * 2 +
      AppDimens.borderThin * 2 +
      // Rounding headroom so the label never lands a hair too wide.
      AppDimens.space2;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusButton);
    final filled = this.filled && !_GoalMetScope.of(context);
    final actionColor = context.colors.primary;
    // Brand cyan is too light as text on light mode: outlined labels use
    // the readable shade.
    final fg = filled
        ? context.vColors.buttonText!
        : context.vColors.accentText ?? actionColor;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: filled
            ? actionColor
            : actionColor.withValues(alpha: AppDimens.tintAlpha),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: actionColor.withValues(
              alpha: filled ? 1 : AppDimens.tintBorderAlpha,
            ),
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDimens.buttonHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space8,
                vertical: AppDimens.space8,
              ),
              // In a narrow button the icon gives way so the label shows
              // whole at its full size.
              child: MeasuredLayoutBuilder(
                measures: LayoutMeasures(
                  maxWidth: () =>
                      widthFor(context, label) - AppDimens.space8 * 2,
                  minWidth: () =>
                      widthFor(context, label, withIcon: false) -
                      AppDimens.space8 * 2,
                  heightFor: (_) => math.max(
                    AppDimens.iconSm,
                    _textHeight(
                      context,
                      label,
                      context.text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                builder: (context, constraints) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (constraints.maxWidth + AppDimens.space8 * 2 >=
                        widthFor(context, label)) ...[
                      if (svgAsset != null)
                        SvgPicture.asset(
                          svgAsset!,
                          width: AppDimens.iconSm,
                          height: AppDimens.iconSm,
                          colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                        )
                      else if (icon != null)
                        Icon(icon, size: AppDimens.iconSm, color: fg),
                      const SizedBox(width: AppDimens.space6),
                    ],
                    Flexible(
                      child: FitText(
                        label,
                        maxLines: 1,
                        style: context.text.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

/// Figure with its goal on the line below ("of 2.5 L"), a progress bar
/// and a hint line: today's progress, the same on every card and in the
/// Today summary. The figure keeps one size everywhere; it never shares a
/// line with the goal, so side-by-side tiles always read alike.
class TrackerProgress extends StatelessWidget {
  final String value;
  final String? goal;

  /// Word before the goal: "of 2.5 L", or "Goal 70.0 kg" for a target.
  final String goalPrefix;
  final double? fraction;
  final Color color;
  final String? caption;

  const TrackerProgress({
    super.key,
    required this.value,
    required this.color,
    this.goal,
    this.goalPrefix = 'of',
    this.fraction,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitText.rich(figureSpan(context, value), semanticsLabel: value),
        if (goal != null)
          FitText(
            '$goalPrefix $goal',
            style: context.text.bodyMedium?.copyWith(color: grey),
          ),
        if (fraction != null) ...[
          const SizedBox(height: AppDimens.space8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction!.clamp(0.0, 1.0)),
            duration: AppDurations.slow,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => AppProgressBar(value: v, color: color),
          ),
        ],
        if (caption != null) ...[
          const SizedBox(height: AppDimens.space8),
          Text(caption!, style: context.text.bodySmall?.copyWith(color: grey)),
        ],
      ],
    );
  }
}

/// A figure in the metric style with its units smaller and grey: "72.4"
/// big and "kg" small, "7h 12m" with small h and m. Reads cleaner and
/// takes less room, so half-width tiles keep their figures whole.
TextSpan figureSpan(BuildContext context, String value) {
  final number = AppTextStyles.metric.copyWith(color: context.colors.onSurface);
  final unit = context.text.bodyLarge?.copyWith(
    color: context.vColors.grayText,
  );
  return TextSpan(
    style: number,
    children: [
      for (final m in RegExp(r'[0-9.,:]+|[^0-9.,:]+').allMatches(value))
        TextSpan(
          text: m[0],
          style: RegExp(r'^[0-9.,:]+$').hasMatch(m[0]!) ? null : unit,
        ),
    ],
  );
}

/// Small labelled figure ("Avg 7h 10m") used in rows of two or three.
class TrackerFigure extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final String? iconAsset;
  final Color? color;

  const TrackerFigure({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconAsset,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Row(
      children: [
        if (iconAsset != null) ...[
          SvgPicture.asset(
            iconAsset!,
            width: AppDimens.iconSm,
            height: AppDimens.iconSm,
            colorFilter: ColorFilter.mode(color ?? grey!, BlendMode.srcIn),
          ),
          const SizedBox(width: AppDimens.space6),
        ] else if (icon != null) ...[
          Icon(icon, size: AppDimens.iconSm, color: color ?? grey),
          const SizedBox(width: AppDimens.space6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: grey),
              ),
              const SizedBox(height: AppDimens.space2),
              FitText(
                value,
                maxLines: 1,
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Row of [TrackerFigure]s in equal columns.
class TrackerFigureRow extends StatelessWidget {
  final List<TrackerFigure> figures;

  const TrackerFigureRow({super.key, required this.figures});

  @override
  Widget build(BuildContext context) => AdaptiveRow(children: figures);
}

/// Circular progress with the value in the middle — detail-page hero.
class TrackerRing extends StatelessWidget {
  final double? fraction;
  final Color color;
  final Widget center;
  final double size;

  const TrackerRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.center,
    this.size = AppDimens.trackerRing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (fraction ?? 0).clamp(0.0, 1.0)),
              duration: AppDurations.slow,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: AppDimens.trackerRingStroke,
                color: color,
                backgroundColor: context.vColors.track,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              AppDimens.trackerRingStroke + AppDimens.space4,
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: center),
          ),
        ],
      ),
    );
  }
}

/// Progress ring with a figure and a one-word caption inside ("760",
/// "kcal left"): the hero of the Home Nutrition and Activity cards. The
/// ring grows with the text size, so its figure never has to shrink.
class TrackerHeroRing extends StatelessWidget {
  final double? fraction;
  final Color color;
  final String value;
  final String caption;

  const TrackerHeroRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.value,
    required this.caption,
  });

  /// Outer size at the current text size: it grows like the big figures
  /// (the metric style), less than body text.
  static double sizeOf(BuildContext context) =>
      AppDimens.trackerRing * metricGrowth(context);

  @override
  Widget build(BuildContext context) {
    final f = fraction;
    return Semantics(
      label: '$value $caption',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: sizeOf(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: f != null && f.isFinite ? f.clamp(0.0, 1.0) : 0.0,
              ),
              duration: AppDurations.slow,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: AppDimens.trackerRingStroke,
                color: color,
                backgroundColor: context.vColors.track,
                strokeCap: StrokeCap.round,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(
                AppDimens.trackerRingStroke + AppDimens.space4,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FitText(
                    value,
                    textAlign: TextAlign.center,
                    // Same weight as the Today card's figures.
                    style: context.text.titleMedium?.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  FitText(
                    caption,
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A [TrackerHeroRing] with its [details] (macros, goal figure) beside it,
/// or centred above them only when the details would get too narrow (a
/// narrow phone at large text), never just because text is large.
class TrackerHeroLayout extends StatelessWidget {
  final Widget ring;
  final Widget details;

  const TrackerHeroLayout({
    super.key,
    required this.ring,
    required this.details,
  });

  /// Narrowest the details may get beside the ring: "of 10,000 steps"
  /// at full size.
  static const double _minDetailsWidth = 124;

  @override
  Widget build(BuildContext context) {
    const gap = AppDimens.space16;
    return LayoutBuilder(
      builder: (context, constraints) {
        final beside =
            constraints.maxWidth - TrackerHeroRing.sizeOf(context) - gap >=
            context.textScaled(_minDetailsWidth);
        if (beside) {
          return Row(
            children: [
              ring,
              const SizedBox(width: gap),
              Expanded(child: details),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: ring),
            const SizedBox(height: AppDimens.space16),
            details,
          ],
        );
      },
    );
  }
}

/// One quiet grey line of facts under a card's hero ("1,240 of 2,000 kcal
/// · 2 of 4 meals"). It wraps only between facts, never inside one.
class TrackerSummaryLine extends StatelessWidget {
  final List<String> parts;
  final TextAlign? textAlign;

  const TrackerSummaryLine({super.key, required this.parts, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return Text(
      parts.map((p) => p.replaceAll(' ', '\u00a0')).join('  ·  '),
      textAlign: textAlign,
      style: context.text.bodySmall?.copyWith(color: context.vColors.grayText),
    );
  }
}

/// One named figure with a bar: "Protein ... 68 / 150g" over its
/// progress. Macros and secondary activity goals both use it, so every
/// bar row on Home reads the same: name in body text, figure in small grey
/// (it drops under the name when both don't fit), standard bar.
class TrackerBarRow extends StatelessWidget {
  final String name;
  final String figure;
  final double fraction;
  final Color color;

  /// The goal is met: a green check before the figure.
  final bool done;

  const TrackerBarRow({
    super.key,
    required this.name,
    required this.figure,
    required this.fraction,
    required this.color,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Semantics(
      label: '$name $figure${done ? ', goal met' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimens.space8,
            children: [
              Text(
                name,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    if (done)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: AppDimens.space4,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: AppDimens.iconXs,
                            color: context.iconTint(context.vColors.success!),
                          ),
                        ),
                      ),
                    TextSpan(text: figure),
                  ],
                ),
                style: context.text.bodySmall?.copyWith(color: grey),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space6),
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0,
            ),
            duration: AppDurations.slow,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => AppProgressBar(value: v, color: color),
          ),
        ],
      ),
    );
  }
}

/// Section heading on tracker pages with an optional trailing action.
class TrackerSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const TrackerSectionTitle(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: context.text.headlineSmall)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.space8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                const Icon(Icons.chevron_right_rounded, size: AppDimens.iconMd),
              ],
            ),
          ),
      ],
    );
  }
}

/// One logged entry: leading icon badge, title/subtitle, trailing value.
/// With [onDelete] it swipes left to delete.
class TrackerLogTile extends StatelessWidget {
  final Object id;
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final Future<void> Function()? onDelete;

  const TrackerLogTile({
    super.key,
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    this.trailing,
    this.subtitle,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tile = AppCard(
      width: double.infinity,
      sheen: false,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space16,
        vertical: AppDimens.space12,
      ),
      child: Row(
        children: [
          AppIconBadge(
            color: color,
            icon: Icon(icon, size: AppDimens.iconMd, color: color),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppDimens.space8),
            Text(trailing!, style: context.text.titleSmall),
          ],
        ],
      ),
    );
    if (onDelete == null) return tile;
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimens.space20),
        decoration: BoxDecoration(
          color: context.vColors.errorFill,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Icon(Icons.delete_outline_rounded, color: context.colors.error),
      ),
      onDismissed: (_) => onDelete!(),
      child: tile,
    );
  }
}

/// Empty screen of a tracker's history page: metric badge, title and one
/// line, centred. Every history page uses it so they read the same.
class TrackerEmptyState extends StatelessWidget {
  final TrackerMetric metric;
  final String title;
  final String message;

  const TrackerEmptyState({
    super.key,
    required this.metric,
    this.title = 'Nothing logged yet',
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrackerBadge(metric, size: AppDimens.iconBadgeLarge),
          const SizedBox(height: AppDimens.space16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Spinner sized like a card body while a tracker loads.
class TrackerLoading extends StatelessWidget {
  final Color? color;

  const TrackerLoading({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space32),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: AppDimens.borderThick,
          color: color ?? context.colors.primary,
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }
}

/// Card shell while loading, or "Couldn't load" + Retry on failure: the
/// same on full-width cards and half-width tiles, shaped like a loaded
/// card (header, prompt, one button).
class TrackerCardPlaceholder extends StatelessWidget {
  final TrackerMetric metric;
  final VoidCallback? onRetry;
  final String? title;

  const TrackerCardPlaceholder({
    super.key,
    required this.metric,
    this.onRetry,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerCard(
      metric: metric,
      title: title,
      actions: [
        if (onRetry != null)
          TrackerQuickAction(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            color: metric.color,
            onTap: onRetry,
          ),
      ],
      child: onRetry == null
          ? TrackerLoading(color: metric.color)
          : TrackerPrompt(title: "Couldn't load", color: metric.color),
    );
  }
}

/// Inline prompt inside a card or page: icon, title, optional message and
/// an optional action — empty states and permission requests.
class TrackerPrompt extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? message;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? maxLines;

  const TrackerPrompt({
    super.key,
    this.icon,
    required this.title,
    this.message,
    required this.color,
    this.actionLabel,
    this.onAction,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppDimens.iconLg, color: color),
              const SizedBox(width: AppDimens.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppDimens.space4),
                    Text(
                      message!,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.vColors.grayText,
                      ),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: AppDimens.cardInnerGap),
          TrackerQuickAction(
            label: actionLabel!,
            icon: Icons.arrow_forward_rounded,
            color: color,
            onTap: onAction,
          ),
        ],
      ],
    );
  }
}

/// Marks tracker cards laid out as side-by-side Home tiles.
class _TileScope extends InheritedWidget {
  const _TileScope({required super.child});

  static bool inTile(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_TileScope>() != null;

  @override
  bool updateShouldNotify(_TileScope old) => false;
}

/// How much the metric style (big card figures) has grown with the
/// system text size: less than body text ([AppTextScaler]).
double metricGrowth(BuildContext context) {
  final size = AppTextStyles.metric.fontSize!;
  return MediaQuery.textScalerOf(context).scale(size) / size;
}

/// Two half-width tracker tiles side by side at a shared height, which
/// grows with the system text size so tile content never clips (never
/// below the base height: icons, padding and buttons don't shrink). Only
/// when a tile would get narrower than [AppDimens.dashboardTileMinWidth]
/// grown like the tiles' figures do the two stack as full-width tiles at
/// their own height, so figures keep their full size. The layout changes
/// with the room there is, not at one text size for the whole page.
class TrackerTilePair extends StatelessWidget {
  final Widget left;
  final Widget right;

  const TrackerTilePair({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - AppDimens.cardGap) / 2;
        // Tiles need room for their figures, and the metric style grows
        // less than body text with the system size.
        if (tileWidth <
            AppDimens.dashboardTileMinWidth * metricGrowth(context)) {
          return Column(
            children: [
              left,
              const SizedBox(height: AppDimens.cardGap),
              right,
            ],
          );
        }
        return _row(context);
      },
    );
  }

  Widget _row(BuildContext context) {
    final height = context.textScaled(AppDimens.dashboardTileHeight);
    return _TileScope(
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppDimens.cardGap),
            Expanded(child: right),
          ],
        ),
      ),
    );
  }
}
