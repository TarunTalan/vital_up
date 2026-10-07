import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Avatar from a URL, falling back to the name's initial. Round by default;
/// pass [borderRadius] for the rounded-square profile avatar.
class UserAvatar extends StatelessWidget {
  final String username;
  final String? url;
  final double size;
  final Color? ringColor;
  final double? borderRadius;
  final TextStyle? initialStyle;

  const UserAvatar({
    super.key,
    required this.username,
    this.url,
    this.size = AppDimens.avatarSmall,
    this.ringColor,
    this.borderRadius,
    this.initialStyle,
  });

  @override
  Widget build(BuildContext context) {
    final initial = username.isEmpty
        ? '?'
        : username.characters.first.toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: (initialStyle ?? context.text.titleSmall)?.copyWith(
          color: context.colors.primary,
        ),
      ),
    );
    final rounded = borderRadius == null
        ? null
        : BorderRadius.circular(borderRadius!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: rounded == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: rounded,
        color: context.colors.primary.withValues(alpha: 0.15),
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: AppDimens.borderThick),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? fallback
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
