import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';

/// Opens the share sheet with an invite that names [username] when known.
Future<void> shareInvite(String? username) => SharePlus.instance.share(
  ShareParams(
    text: username != null && username.isNotEmpty
        ? 'Join me on VitalUp to track health goals and take on '
              'challenges together. Add me: @$username'
        : 'Join me on VitalUp to track health goals and take on '
              'challenges together.',
  ),
);

/// "Share invite" and "Copy @username" side by side, so friends can find
/// the caller.
class InviteButtons extends StatelessWidget {
  final String? myUsername;

  const InviteButtons({super.key, this.myUsername});

  bool get _hasUsername => myUsername != null && myUsername!.isNotEmpty;

  void _copyUsername(BuildContext context) {
    Clipboard.setData(ClipboardData(text: '@$myUsername'));
    showSuccessSnackBar(context, 'Copied @$myUsername');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppSecondaryButton(
            label: 'Share invite',
            leadingIcon: const Icon(
              Icons.share_rounded,
              size: AppDimens.iconSm,
            ),
            onTap: () => shareInvite(myUsername),
          ),
        ),
        if (_hasUsername) ...[
          const SizedBox(width: AppDimens.buttonGap),
          Expanded(
            child: AppSecondaryButton(
              label: '@$myUsername',
              leadingIcon: const Icon(
                Icons.copy_rounded,
                size: AppDimens.iconSm,
              ),
              onTap: () => _copyUsername(context),
            ),
          ),
        ],
      ],
    );
  }
}
