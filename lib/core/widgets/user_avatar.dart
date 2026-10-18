import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Avatar from a URL, falling back to the name's initial. Circular by design
/// across all screens in the app.
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
          color: context.vColors.accentText,
        ),
      ),
    );
    // Decode at the shown size: uploads are up to 1024 px, and a full-size
    // decode per row filled the image cache on leaderboards.
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    Widget imageWidget;
    final trimmedUrl = url?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      imageWidget = fallback;
    } else if (trimmedUrl.startsWith('http://') ||
        trimmedUrl.startsWith('https://')) {
      imageWidget = Image.network(
        trimmedUrl,
        width: size,
        height: size,
        cacheWidth: decodeWidth,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (trimmedUrl.startsWith('assets/')) {
      imageWidget = Image.asset(
        trimmedUrl,
        width: size,
        height: size,
        cacheWidth: decodeWidth,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      imageWidget = Image.file(
        File(trimmedUrl.replaceFirst('file://', '')),
        width: size,
        height: size,
        cacheWidth: decodeWidth,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.primary.withValues(alpha: 0.15),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(child: imageWidget),
          if (ringColor != null)
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ringColor!,
                  width: AppDimens.borderThick,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
