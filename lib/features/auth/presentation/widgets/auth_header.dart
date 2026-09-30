import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';

/// Top header for auth screens (Figma login / sign up frames):
/// 48dp back button, then a centred "Large Title".
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.space20,
          context.gutter,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BackIcon(onClick: onBackClick),
            ),
            SizedBox(height: context.h(AppDimens.space32)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                headerText,
                textAlign: TextAlign.center,
                style: context.text.displayLarge?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
