import 'package:flutter/material.dart';

/// Small circular icon button used for the back button and similar
/// floating controls over the map.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.black, size: 18),
        ),
      ),
    );
  }
}

/// Floating button that re-centers the map camera on the user's location.
class ZoomResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ZoomResetButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.my_location_rounded,
            color: Colors.black,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Icon that reflects the current state of the offline map download
/// (not started / downloading / ready).
class OfflineMapIcon extends StatelessWidget {
  final bool isReady;
  final bool isDownloading;
  final double progress;
  final VoidCallback onTap;

  const OfflineMapIcon({
    super.key,
    required this.isReady,
    required this.isDownloading,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    if (isReady) {
      icon = Icons.offline_pin_rounded;
      color = const Color(0xFF47B85A);
    } else if (isDownloading) {
      icon = Icons.downloading_rounded;
      color = const Color(0xFF2BC7D8);
    } else {
      icon = Icons.download_for_offline_rounded;
      color = const Color(0xFF777777);
    }

    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}