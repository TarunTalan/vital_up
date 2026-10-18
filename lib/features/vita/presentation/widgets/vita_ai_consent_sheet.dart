import 'package:flutter/material.dart';
import 'package:vital_up/core/config/legal_links.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/features/vita/data/services/vita_ai_consent.dart';

/// True when the AI may be used: accepted before, or accepted now. Call it
/// before anything that sends data to Vita or the diet plan generator.
Future<bool> ensureVitaAiConsent(BuildContext context) async {
  if (sl<VitaAiConsent>().accepted) return true;
  return showVitaAiConsentSheet(context);
}

/// The AI data notice. Before the first AI use it asks to agree; from
/// Settings ([manage]) it also lets the user change the Health Connect
/// choice or stop sharing. True when the AI may be used afterwards.
Future<bool> showVitaAiConsentSheet(
  BuildContext context, {
  bool manage = false,
}) async {
  final result = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => _VitaAiConsentSheet(manage: manage),
  );
  return result ?? sl<VitaAiConsent>().accepted;
}

class _VitaAiConsentSheet extends StatefulWidget {
  final bool manage;

  const _VitaAiConsentSheet({required this.manage});

  @override
  State<_VitaAiConsentSheet> createState() => _VitaAiConsentSheetState();
}

class _VitaAiConsentSheetState extends State<_VitaAiConsentSheet> {
  final _consent = sl<VitaAiConsent>();
  late bool _healthConnect = _consent.includeHealthConnect;
  bool _saving = false;

  bool get _accepted => _consent.accepted;

  Future<void> _accept() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _consent.accept(includeHealthConnect: _healthConnect);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _withdraw() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _consent.withdraw();
    if (!mounted) return;
    Navigator.pop(context, false);
    showSuccessSnackBar(context, 'Vita and AI plans are off until you agree.');
  }

  Future<void> _openPolicy() async {
    final opened = await LegalLinks.open(LegalLinks.privacyPolicy);
    if (!opened && mounted) {
      showErrorSnackBar(context, "Couldn't open the privacy policy.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final managing = widget.manage && _accepted;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your data and the AI coach', style: context.text.headlineSmall),
            const SizedBox(height: AppDimens.space8),
            Text(
              'To answer you, Vita and the diet plan generator send this to '
              'our server, which asks Google Gemini (or Groq when Gemini is '
              'unavailable):',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: AppDimens.space12),
            const _Point(
              icon: Icons.chat_bubble_outline_rounded,
              text: 'Your questions and plan choices',
            ),
            const _Point(
              icon: Icons.person_outline_rounded,
              text: 'Profile basics: age, sex, height, weight and goals',
            ),
            const _Point(
              icon: Icons.restaurant_rounded,
              text: 'What you log: meals, water, sleep, weight, mood, '
                  'workouts and screen time',
            ),
            const _Point(
              icon: Icons.medical_information_outlined,
              text: 'Health answers: conditions, medicines, allergies, '
                  'smoking and blood pressure',
            ),
            const SizedBox(height: AppDimens.space8),
            AppListTile(
              icon: Icons.monitor_heart_outlined,
              title: 'Include Health Connect readings',
              subtitle: 'Heart rate, HRV, blood oxygen, blood pressure, '
                  'steps and sleep',
              trailing: Switch(
                value: _healthConnect,
                onChanged: _saving
                    ? null
                    : (on) => setState(() => _healthConnect = on),
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            const AppInfoNote(
              icon: Icons.lock_outline_rounded,
              message: 'Never used for ads or sold. You can change this any '
                  'time in Settings > Privacy & security.',
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _openPolicy,
                child: Text(
                  'Read the privacy policy',
                  style: context.text.labelLarge?.copyWith(
                    color: context.vColors.accentText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            AppPrimaryButton(
              label: managing ? 'Save' : 'Agree and continue',
              isLoading: _saving,
              enabled: !_saving,
              onTap: _accept,
            ),
            const SizedBox(height: AppDimens.space8),
            AppSecondaryButton(
              label: managing ? 'Stop sharing with the AI' : 'Not now',
              enabled: !_saving,
              onTap: managing
                  ? _withdraw
                  : () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimens.space8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppDimens.iconMd, color: context.vColors.grayText),
        const SizedBox(width: AppDimens.space12),
        Expanded(child: Text(text, style: context.text.bodyMedium)),
      ],
    ),
  );
}
