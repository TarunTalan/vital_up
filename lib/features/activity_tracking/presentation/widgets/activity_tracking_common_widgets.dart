import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Floating circular control over the map — Figma `button/ ArrowLeft`
/// (48dp circle, "shadow black y", 24dp icon) on an opaque surface so it
/// stays legible over map tiles.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: AppDimens.backButtonSize,
      height: AppDimens.backButtonSize,
      decoration: BoxDecoration(
        color: context.vColors.surfaceElevated,
        shape: BoxShape.circle,
        boxShadow: AppShadows.shadowY,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(
            icon,
            color: context.colors.onSurface,
            size: AppDimens.iconLg,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Floating button that re-centers the map camera on the user's location.
class ZoomResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ZoomResetButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return RoundIconButton(
      icon: Icons.my_location_rounded,
      onPressed: onPressed,
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
    final IconData icon;
    final Color? color;

    if (isReady) {
      icon = Icons.offline_pin_rounded;
      color = context.vColors.success;
    } else if (isDownloading) {
      icon = Icons.downloading_rounded;
      color = context.colors.primary;
    } else {
      icon = Icons.download_for_offline_rounded;
      color = context.vColors.grayText;
    }

    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: AppDimens.iconLg),
    );
  }
}
