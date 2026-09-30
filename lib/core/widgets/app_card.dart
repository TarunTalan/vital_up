import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Glass card — Figma `card/*`:
/// radius 16, rgba(186,186,186,0.13) fill + subtle cyan sheen,
/// rgba(186,186,186,0.27) 1px border, optional 15.3 background blur.
///
/// This is the single card surface for the whole app. Use [highlighted] for
/// the cyan "insight" variant and [tint] for a solid coloured fill.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;
  final bool blur;
  final bool sheen;
  final bool highlighted;
  final Color? tint;
  final Color? borderColor;
  final double? width;
  final List<BoxShadow>? shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppDimens.cardPadding,
    this.margin,
    this.onTap,
    this.radius = AppDimens.radiusCard,
    this.blur = false,
    this.sheen = true,
    this.highlighted = false,
    this.tint,
    this.borderColor,
    this.width,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final borderRadius = BorderRadius.circular(radius);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: tint ?? v.glassFill,
        gradient: highlighted
            ? AppColors.insightSheen
            : (sheen && tint == null ? AppColors.glassSheen : null),
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? v.glassBorder!,
          width: AppDimens.borderThin,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    // The sheen gradient replaces the flat fill, so layer the fill underneath.
    if (sheen && tint == null) {
      content = DecoratedBox(
        decoration: BoxDecoration(color: v.glassFill, borderRadius: borderRadius),
        child: content,
      );
    }

    if (blur) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppDimens.glassBlur / 2,
            sigmaY: AppDimens.glassBlur / 2,
          ),
          child: content,
        ),
      );
    }

    if (shadow != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
        child: content,
      );
    }

    return Container(width: width, margin: margin, child: content);
  }
}

/// Coloured circular badge behind a card icon — Figma 40dp circle with
/// 20% tint of the accent colour.
class AppIconBadge extends StatelessWidget {
  final Widget icon;
  final Color? color;
  final double size;

  const AppIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = AppDimens.iconBadge,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.colors.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconTheme(
        data: IconThemeData(color: accent, size: size / 2),
        child: icon,
      ),
    );
  }
}

/// 8dp rounded progress bar — Figma `Progress Bar`.
class AppProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? trackColor;
  final double height;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = AppDimens.progressHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color ?? context.vColors.success,
        backgroundColor: trackColor ?? context.vColors.track,
      ),
    );
  }
}

/// Uppercase eyebrow label used at the top of cards
/// (Figma "caption 12", e.g. "TODAY'S INSIGHTS").
class AppCaption extends StatelessWidget {
  final String text;
  final Color? color;

  const AppCaption(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        color: color ?? context.vColors.grayText,
      ),
    );
  }
}

/// Inline info note — Figma `toast/info`: 12 radius, #D8D8D8 hairline,
/// 18dp info icon, "small reg 14" grey text.
class AppInfoNote extends StatelessWidget {
  final String message;
  final IconData icon;

  const AppInfoNote({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Container(
      width: double.infinity,
      padding: AppDimens.toastPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusToast),
        border: Border.all(color: context.vColors.hairline!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppDimens.iconSm, color: grey),
          const SizedBox(width: AppDimens.space6),
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: grey),
            ),
          ),
        ],
      ),
    );
  }
}
