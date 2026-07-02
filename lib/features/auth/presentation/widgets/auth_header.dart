import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';

/// Top header for auth screens: back arrow + left-aligned page title.
/// Background decoration is handled by the parent [AuthBackground].
class AuthHeader extends StatelessWidget {
  final String headerText;
  final VoidCallback onBackClick;

  const AuthHeader({
    super.key,
    required this.headerText,
    required this.onBackClick,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = AppTheme.hPadding;
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = (screenWidth * 0.08).clamp(24.0, 36.0);

    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back arrow row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8.0),
            child: BackIcon(onClick: onBackClick),
          ),
          // Page title — Figma: 36sp w600 #1C1C1C, centered
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Text(
                headerText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: titleFontSize,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
