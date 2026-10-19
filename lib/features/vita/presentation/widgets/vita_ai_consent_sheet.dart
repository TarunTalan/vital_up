import 'package:flutter/material.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_ai_data_page.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/features/vita/data/services/vita_ai_consent.dart';

/// True when the AI may be used: accepted before, or accepted now. Call it
/// before anything that sends data to Vita or the diet plan generator.
Future<bool> ensureVitaAiConsent(BuildContext context) async {
  if (sl<VitaAiConsent>().accepted) return true;
  return showVitaAiConsentSheet(context);
}

/// The AI data notice shown before the first AI use: a short summary, the
/// Health Connect choice and Agree / Not now. The full details and later
/// changes live on the AI coach data page (Settings > Privacy & security).
/// True when the AI may be used afterwards.
Future<bool> showVitaAiConsentSheet(BuildContext context) async {
  final result = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => const _VitaAiConsentSheet(),
  );
  return result ?? sl<VitaAiConsent>().accepted;
}

class _VitaAiConsentSheet extends StatefulWidget {
  const _VitaAiConsentSheet();

  @override
  State<_VitaAiConsentSheet> createState() => _VitaAiConsentSheetState();
}

class _VitaAiConsentSheetState extends State<_VitaAiConsentSheet> {
  final _consent = sl<VitaAiConsent>();
  late bool _healthConnect = _consent.includeHealthConnect;
  bool _saving = false;

  Future<void> _accept() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _consent.accept(includeHealthConnect: _healthConnect);
    if (mounted) Navigator.pop(context, true);
  }

  /// The full details page, on top of this sheet. Sharing turned on there
  /// counts as agreeing here.
  Future<void> _openDetails() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const VitaAiDataPage()));
    if (!mounted) return;
    if (_consent.accepted) {
      Navigator.pop(context, true);
    } else {
      setState(() => _healthConnect = _consent.includeHealthConnect);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              'Your data and the AI coach',
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: AppDimens.space8),
            Text(
              'To answer you, Vita and AI plans send your questions, profile '
              'basics and what you log to Google Gemini. Never used for ads '
              'or sold.',
              style: context.text.bodyMedium,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _openDetails,
                child: Text(
                  "See what's shared",
                  style: context.text.labelLarge?.copyWith(
                    color: context.vColors.accentText,
                  ),
                ),
              ),
            ),
            AppListTile(
              icon: Icons.monitor_heart_outlined,
              title: 'Include Health Connect readings',
              subtitle:
                  'Heart rate, HRV, blood oxygen, blood pressure, '
                  'steps and sleep',
              trailing: Switch(
                value: _healthConnect,
                onChanged: _saving
                    ? null
                    : (on) => setState(() => _healthConnect = on),
              ),
            ),
            const SizedBox(height: AppDimens.space16),
            AppPrimaryButton(
              label: 'Agree and continue',
              isLoading: _saving,
              enabled: !_saving,
              onTap: _accept,
            ),
            const SizedBox(height: AppDimens.space8),
            AppSecondaryButton(
              label: 'Not now',
              enabled: !_saving,
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
