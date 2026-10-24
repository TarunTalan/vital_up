import 'package:flutter/material.dart';
import 'package:vital_up/core/config/legal_links.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/vita/data/services/vita_ai_consent.dart';
import 'package:vital_up/core/utils/health_store.dart';

/// Settings > Privacy & security > AI coach data: what Vita and AI plans
/// send and to whom, with switches that save at once. The first-use
/// prompt is the short consent sheet ([ensureVitaAiConsent]).
class VitaAiDataPage extends StatefulWidget {
  const VitaAiDataPage({super.key});

  @override
  State<VitaAiDataPage> createState() => _VitaAiDataPageState();
}

class _VitaAiDataPageState extends State<VitaAiDataPage> {
  final _consent = sl<VitaAiConsent>();
  bool _saving = false;

  Future<void> _setSharing(bool on) async {
    if (_saving) return;
    setState(() => _saving = true);
    if (on) {
      await _consent.accept(includeHealthConnect: false);
    } else {
      await _consent.withdraw();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!on) {
      showSuccessSnackBar(
        context,
        'Vita and AI plans are off until you agree.',
      );
    }
  }

  Future<void> _setHealthConnect(bool on) async {
    if (_saving) return;
    setState(() => _saving = true);
    await _consent.setIncludeHealthConnect(on);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _openPolicy() async {
    final opened = await LegalLinks.open(LegalLinks.privacyPolicy);
    if (!opened && mounted) {
      showErrorSnackBar(context, "Couldn't open the privacy policy.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharing = _consent.accepted;
    return AppScaffold(
      header: const AppPageHeader(title: 'AI coach data'),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppListGroup(
            children: [
              AppListTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Use Vita and AI plans',
                subtitle: sharing
                    ? 'Your data is shared to answer you'
                    : 'Off. Nothing is sent to the AI',
                trailing: Switch(
                  value: sharing,
                  onChanged: _saving ? null : _setSharing,
                ),
              ),
              AppListTile(
                icon: Icons.monitor_heart_outlined,
                title: 'Include $healthStoreName readings',
                subtitle: 'Steps, sleep and imported workouts',
                trailing: Switch(
                  value: _consent.includeHealthConnect,
                  // Only with sharing on: never sent without it.
                  onChanged: _saving || !sharing ? null : _setHealthConnect,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sectionGap),
          const AppListGroup(
            title: "What's sent",
            children: [
              AppListTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Your questions',
                subtitle: 'What you ask Vita and your plan choices',
              ),
              AppListTile(
                icon: Icons.person_outline_rounded,
                title: 'Profile basics',
                subtitle: 'Age, sex, height, weight and goals',
              ),
              AppListTile(
                icon: Icons.restaurant_rounded,
                title: 'What you log',
                subtitle:
                    'Meals, water, sleep, weight, mood, workouts and screen '
                    'time',
              ),
              AppListTile(
                icon: Icons.medical_information_outlined,
                title: 'Health answers',
                subtitle:
                    'Conditions, medicines, allergies, smoking and blood '
                    'pressure',
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sectionGap),
          AppListGroup(
            title: 'Who gets it',
            children: [
              const AppListTile(
                icon: Icons.cloud_outlined,
                title: 'Our server and Google Gemini',
                subtitle: 'Groq answers when Gemini is unavailable',
              ),
              AppListTile(
                icon: Icons.policy_outlined,
                title: 'Privacy policy',
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: _openPolicy,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardGap),
          const AppInfoNote(
            icon: Icons.lock_outline_rounded,
            message: 'Never used for ads or sold.',
          ),
        ],
      ),
    );
  }
}
