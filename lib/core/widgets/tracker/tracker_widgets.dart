import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';

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
      colorFilter: ColorFilter.mode(color ?? metric.color, BlendMode.srcIn),
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
      icon: TrackerIcon(metric, size: size / 2),
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
        final isCompact = constraints.maxWidth < 200;
        return Row(
          children: [
            TrackerBadge(metric),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Text(
                title ?? metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            if (status != null && !isCompact) ...[
              const SizedBox(width: AppDimens.space8),
              TrackerStatusChip(status!, label: statusLabel, color: statusColor),
            ],
            if (showChevron && !isCompact) ...[
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

/// Home card shell for a tracker: tapping anywhere opens its detail page;
/// [actions] (quick logs) sit at the bottom. A met goal mutes the card a
/// little so unfinished trackers stand out without reordering.
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
          child: Column(
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
                child!,
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppDimens.cardInnerGap),
                TrackerActionRow(actions: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays quick actions out in equal-width columns.
class TrackerActionRow extends StatelessWidget {
  final List<Widget> actions;

  const TrackerActionRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimens.space8),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

/// Compact tinted button for one-tap logging on cards and sheets
/// ("+250 ml", "Log sleep"). [filled] marks the card's main action.
class TrackerQuickAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? svgAsset;
  final Color color; // We will keep the property for compatibility, but override it visually if we want.
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

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusButton);
    final actionColor = context.colors.primary; // Always use primary for actions
    final fg = filled ? context.vColors.buttonText! : actionColor;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: filled ? actionColor : actionColor.withValues(alpha: AppDimens.tintAlpha),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: context.text.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

/// "value / goal unit" readout with a progress bar and a hint line —
/// today's progress, the same on every card.
class TrackerProgress extends StatelessWidget {
  final String value;
  final String? goal;
  final double? fraction;
  final Color color;
  final String? caption;

  const TrackerProgress({
    super.key,
    required this.value,
    required this.color,
    this.goal,
    this.fraction,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppTextStyles.metric.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                if (goal != null)
                  TextSpan(
                    text: '  / $goal',
                    style: context.text.bodyMedium?.copyWith(color: grey),
                  ),
              ],
            ),
            maxLines: 1,
          ),
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
          const SizedBox(height: AppDimens.space6),
          Text(caption!, style: context.text.bodySmall?.copyWith(color: grey)),
        ],
      ],
    );
  }
}

/// Small labelled figure ("Avg 7h 10m") used in rows of two or three.
class TrackerFigure extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  const TrackerFigure({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Row(
      children: [
        if (icon != null) ...[
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < figures.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimens.space8),
          Expanded(child: figures[i]),
        ],
      ],
    );
  }
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
        ),
      ),
    );
  }
}

/// Card shell while loading, or "couldn't load" + Retry on failure.
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
      child: onRetry == null
          ? TrackerLoading(color: metric.color)
          : LoadErrorView(onRetry: onRetry!),
    );
  }
}

/// Inline prompt inside a card or page: icon, message and an optional
/// action — empty states and permission requests.
class TrackerPrompt extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String message;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const TrackerPrompt({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: AppDimens.space4),
                  Text(
                    message,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
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
