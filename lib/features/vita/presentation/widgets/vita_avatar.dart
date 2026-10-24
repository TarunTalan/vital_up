import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/vita/presentation/utils/vita_icons.dart';

/// Vita's mark in a tinted circle, like every icon badge in the app: the
/// glyph keeps 3:1 on its circle in either theme.
class VitaAvatar extends StatelessWidget {
  final double size;

  const VitaAvatar({super.key, this.size = VitaDimens.avatarSmall});

  const VitaAvatar.large({super.key}) : size = VitaDimens.avatarLarge;

  @override
  Widget build(BuildContext context) {
    return AppIconBadge(
      size: size,
      color: VitaColors.accent,
      icon: SvgPicture.asset(
        VitaIcons.vita,
        width: size / 2,
        height: size / 2,
        colorFilter: ColorFilter.mode(
          AppIconBadge.glyphColor(context, VitaColors.accent),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
