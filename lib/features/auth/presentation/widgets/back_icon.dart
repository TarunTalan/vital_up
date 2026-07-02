import 'package:flutter/material.dart';

class BackIcon extends StatelessWidget {
  final VoidCallback onClick;

  const BackIcon({super.key, required this.onClick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.arrow_back,
              size: 22,
            ),
            color: Theme.of(context).colorScheme.onSurface,
            onPressed: onClick,
          ),
        ),
      ),
    );
  }
}
