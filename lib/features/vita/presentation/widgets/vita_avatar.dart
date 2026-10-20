import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Vita's avatar. Renders the brand character artwork [vita.svg].
class VitaAvatar extends StatelessWidget {
  final double size;
  final Color color;
  final Color? iconColor;

  const VitaAvatar({
    super.key,
    this.size = VitaDimens.avatarSmall,
    this.color = VitaColors.avatar,
    this.iconColor,
  });

  const VitaAvatar.large({super.key, this.iconColor})
    : size = VitaDimens.avatarLarge,
      color = VitaColors.avatar;

  const VitaAvatar.insight({super.key, this.iconColor})
    : size = VitaDimens.avatarSmall,
      color = VitaColors.avatarInsight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SvgPicture.asset(
        'assets/icons/nav/vita.svg',
        width: size * 0.6,
        height: size * 0.6,
        colorFilter: ColorFilter.mode(
          iconColor ?? AppColors.darker,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
