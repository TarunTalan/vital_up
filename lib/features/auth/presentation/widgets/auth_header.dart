import 'package:flutter/material.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/features/auth/presentation/widgets/ellipse_background.dart';

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
    return Container(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const EllipseBackground(height: 140),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BackIcon(onClick: onBackClick),
                  ),
                ),
                Text(
                  headerText,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
