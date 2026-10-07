import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';

/// Invite card: share an invite message, or copy your username so friends
/// can send you a request.
class InviteShareCard extends StatelessWidget {
  final String? myUsername;

  const InviteShareCard({super.key, this.myUsername});

  bool get _hasUsername => myUsername != null && myUsername!.isNotEmpty;

  Future<void> _share() => SharePlus.instance.share(
    ShareParams(
      text: _hasUsername
          ? 'Join me on VitalUp to track health goals and take on '
                'challenges together. Add me: @$myUsername'
          : 'Join me on VitalUp to track health goals and take on '
                'challenges together.',
    ),
  );

  void _copyUsername(BuildContext context) {
    Clipboard.setData(ClipboardData(text: '@$myUsername'));
    showSuccessSnackBar(context, 'Copied @$myUsername');
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: const Icon(Icons.share_rounded),
                color: context.colors.primary,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite friends',
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      'Share your username so friends can add you.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'Share invite',
                  leadingIcon: const Icon(
                    Icons.share_rounded,
                    size: AppDimens.iconSm,
                  ),
                  onTap: _share,
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
          ),
        ],
      ),
    );
  }
}
