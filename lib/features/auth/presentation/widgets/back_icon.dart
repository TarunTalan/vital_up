import 'package:flutter/material.dart';

class BackIcon extends StatelessWidget {
  final VoidCallback onClick;

  const BackIcon({super.key, required this.onClick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0x1AFEFEFE) : Colors.transparent;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              size: 24,
            ),
            color: Theme.of(context).colorScheme.onSurface,
            onPressed: onClick,
          ),
        ),
      ),
    );
  }
}
