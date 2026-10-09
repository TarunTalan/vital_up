import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vital_up/core/config/legal_links.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';

/// Figma "Terms & Conditions" modal (sign up section): lighter surface,
/// radius 20, glass border, numbered list, full-width primary CTA.
class TermsAndConditionsDialog extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onAccept;

  const TermsAndConditionsDialog({
    super.key,
    required this.onDismiss,
    required this.onAccept,
  });

  static const List<String> _terms = [
    'VitalUp is designed to support general health, wellness, and activity tracking, not medical care.',
    'The app does not replace professional medical advice, diagnosis, or treatment.',
    'Always consult a qualified healthcare provider before making health or fitness decisions.',
    'You must be legally eligible to use VitalUp and provide accurate, current information.',
    'You are responsible for safeguarding your account and all activity under it.',
    'Health data you enter is used to personalize insights and improve your experience.',
    'VitalUp is not liable for any loss or damages arising from use of the app.',
    'You retain ownership of your data while granting VitalUp permission to process it.',
    'Data is handled in accordance with our Privacy Policy and applicable laws.',
    'VitalUp may update features or suspend access for misuse or policy violations.',
    'The app is provided "as is" without guarantees of accuracy or availability.',
    'VitalUp provides wellness insights based on user-submitted data and does not guarantee accuracy or outcomes.',
    'The app\'s features may evolve, be modified, or discontinued without prior notice.',
    'Users may not copy, distribute, or exploit any part of the app without written consent.',
  ];

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: AppDimens.space4, sigmaY: AppDimens.space4),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: context.gutter,
          vertical: AppDimens.space32,
        ),
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
          child: Container(
            decoration: BoxDecoration(
              color: v.surfaceElevated,
              borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
              border: Border.all(color: v.glassBorder!, width: AppDimens.borderThin),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.space20,
              vertical: AppDimens.space24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Terms & Conditions',
                    textAlign: TextAlign.center,
                    style: context.text.displayLarge?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.space20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _terms.length; i++)
                          _TermItem(index: i + 1, text: _terms[i]),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppDimens.space8,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  LegalLinks.open(LegalLinks.terms),
                              child: Text(
                                'Full terms of use',
                                style: TextStyle(color: v.termsLink),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  LegalLinks.open(LegalLinks.privacyPolicy),
                              child: Text(
                                'Privacy policy',
                                style: TextStyle(color: v.termsLink),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.space20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                    boxShadow: AppShadows.elevated,
                  ),
                  child: AppPrimaryButton(
                    label: 'Back to login',
                    onTap: onAccept,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermItem extends StatelessWidget {
  final int index;
  final String text;

  const _TermItem({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyMedium?.copyWith(color: context.colors.onSurface);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppDimens.space32,
            child: Text('$index.', style: style, textAlign: TextAlign.end, softWrap: false),
          ),
          const SizedBox(width: AppDimens.space6),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
