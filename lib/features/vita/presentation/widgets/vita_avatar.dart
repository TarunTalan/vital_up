import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Vita's avatar. Figma currently shows a plain placeholder circle; swap the
/// body here once the Vita character artwork is ready.
class VitaAvatar extends StatelessWidget {
  final double size;
  final Color color;

  const VitaAvatar({
    super.key,
    this.size = VitaDimens.avatarSmall,
    this.color = VitaColors.avatar,
  });

  const VitaAvatar.large({super.key})
      : size = VitaDimens.avatarLarge,
        color = VitaColors.avatar;

  const VitaAvatar.insight({super.key})
      : size = VitaDimens.avatarSmall,
        color = VitaColors.avatarInsight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
