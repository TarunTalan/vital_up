import 'package:flutter/material.dart';

/// Draws bg.png as a full-screen background behind [child].
///
/// A solid white base is always painted first so that any transparent
/// pixels in bg.png fall back to the scaffold background color
/// (previously the Scaffold itself provided this via scaffoldBackgroundColor;
/// now it is provided explicitly here so the Scaffold can be transparent).
class AuthBackground extends StatelessWidget {
  final Widget child;
  final AuthBackgroundStyle style;

  const AuthBackground({
    super.key,
    required this.child,
    this.style = AuthBackgroundStyle.blobs,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        // 1. Solid light base — fills transparent parts of bg.png
        Positioned.fill(
          child: ColoredBox(color: bgColor),
        ),
        // 2. Background image on top of the solid base
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg.png',
            fit: BoxFit.cover,
          ),
        ),
        // 3. Screen content
        child,
      ],
    );
  }
}

/// Kept for API compatibility — callers may pass a style without effect.
enum AuthBackgroundStyle {
  blobs,
  ellipses,
}
