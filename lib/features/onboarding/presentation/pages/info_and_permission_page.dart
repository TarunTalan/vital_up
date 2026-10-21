import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/permissions/permission_card.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/features/health_sync/health_import_service.dart';
import 'package:vital_up/features/onboarding/data/starting_goals_writer.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/usecases/starting_goals.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';

/// Step 7: what VitalUp keeps and never does, and the user's choices.
/// The analytics and health sync switches are the real settings (shown as
/// they are, saved at once); reminders are turned on once the answers are
/// saved. Continue here saves everything ([submit]) and the starting
/// goals worked out from the answers ([StartingGoals]).
class PrivacyStep extends StatefulWidget {
  final int revealFrom;

  const PrivacyStep({super.key, this.revealFrom = 3});

  @override
  State<PrivacyStep> createState() => _PrivacyStepState();
}

class _PrivacyStepState extends State<PrivacyStep> with OnboardingStepState {
  bool _reminders = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsCubit>();
    if (settings.state is! SettingsLoaded) settings.loadSettings();
  }

  @override
  Future<bool> submit() async {
    final cubit = context.read<OnboardingCubit>();
    await cubit.submitOnboardingDataToBackend();
    if (!mounted) return false;
    final state = cubit.state;
    if (state.status != SubmissionStatus.success) {
      showErrorSnackBar(
        context,
        state.errorMessage ?? "Couldn't save your details. Try again.",
      );
      return false;
    }
    // Before the finish screen, which shows them.
    await sl<StartingGoalsWriter>().save(StartingGoals.from(state));
    if (_reminders) _enableReminders();
    return true;
  }

  /// Asks for notification access and turns on the starter reminders.
  Future<void> _enableReminders() async {
    // The system asks now; Home's notification card mustn't ask again.
    await markPermissionAsked(homeNotificationsKey);
    try {
      await sl<RemindersService>().enableStarterSet();
    } catch (e) {
      debugPrint('Starter reminders not enabled: $e');
    }
  }

  void _save(SettingsEntity settings) =>
      context.read<SettingsCubit>().updateSettings(settings);

  /// Same as Settings > Health sync: on only once access is allowed.
  Future<void> _setHealthSync(SettingsEntity settings, bool on) async {
    if (!on) {
      _save(settings.copyWith(healthSyncEnabled: false));
      return;
    }
    setState(() => _connecting = true);
    var connected = false;
    try {
      connected = await sl<HealthImportService>().connect();
    } catch (e) {
      debugPrint('Health connect failed: $e');
    }
    if (!mounted) return;
    setState(() => _connecting = false);
    if (!connected) {
      showErrorSnackBar(context, 'Allow health data access to turn this on.');
      return;
    }
    _save(settings.copyWith(healthSyncEnabled: true));
  }

  @override
  Widget build(BuildContext context) {
    var i = widget.revealFrom;
    final v = context.vColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingReveal(
          index: i++,
          child: _FactsCard(
            title: 'What we keep',
            facts: [
              _Fact(
                'Health details you share',
                svg: 'assets/icons/onboarding/Stethoscope.svg',
                fallback: Icons.medical_services_rounded,
              ),
              _Fact(
                'Readings from apps you connect',
                svg: 'assets/icons/onboarding/Watch.svg',
                fallback: Icons.watch_rounded,
              ),
              _Fact(
                'Your app preferences',
                svg: 'assets/icons/ui/settings.svg',
                fallback: Icons.settings_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        OnboardingReveal(
          index: i++,
          child: _FactsCard(
            title: 'Our promise',
            accent: v.success,
            facts: const [
              _Fact('We never sell your data', fallback: Icons.check_rounded),
              _Fact(
                'Nothing is posted without your say',
                fallback: Icons.check_rounded,
              ),
              _Fact(
                'We never contact anyone for you',
                fallback: Icons.check_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),
        OnboardingReveal(
          index: i++,
          child: BlocBuilder<SettingsCubit, SettingsState>(
            buildWhen: (a, b) => b is SettingsLoaded || a is! SettingsLoaded,
            builder: (context, state) {
              final settings = state is SettingsLoaded ? state.settings : null;
              return AppListGroup(
                title: 'Your choices',
                children: [
                  AppListTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Health reminders',
                    subtitle: 'Gentle nudges for water, meals and sleep',
                    trailing: Switch(
                      value: _reminders,
                      onChanged: (on) => setState(() => _reminders = on),
                    ),
                  ),
                  AppListTile(
                    icon: Icons.sync_rounded,
                    iconColor: v.success,
                    title: 'Health sync',
                    subtitle: 'Import weight and workouts from Health Connect',
                    trailing: Switch(
                      value: settings?.healthSyncEnabled ?? false,
                      onChanged: settings == null || _connecting
                          ? null
                          : (on) => _setHealthSync(settings, on),
                    ),
                  ),
                  AppListTile(
                    icon: Icons.insights_rounded,
                    title: 'Share usage analytics',
                    subtitle: 'App opens and screens only. No health data.',
                    trailing: Switch(
                      value: settings?.analyticsEnabled ?? true,
                      onChanged: settings == null
                          ? null
                          : (on) =>
                                _save(settings.copyWith(analyticsEnabled: on)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        OnboardingReveal(
          index: i++,
          child: const AppInfoNote(
            icon: Icons.lock_outline_rounded,
            message: 'You can change these any time in Settings.',
          ),
        ),
      ],
    );
  }
}

class _Fact {
  final String text;
  final String? svg;
  final IconData fallback;

  const _Fact(this.text, {this.svg, required this.fallback});
}

/// Static card: a title over icon rows.
class _FactsCard extends StatelessWidget {
  final String title;
  final List<_Fact> facts;
  final Color? accent;

  const _FactsCard({required this.title, required this.facts, this.accent});

  @override
  Widget build(BuildContext context) {
    final color = accent ?? context.colors.primary;
    final glyph = AppIconBadge.glyphColor(context, color);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.text.titleSmall),
          for (final fact in facts) ...[
            const SizedBox(height: AppDimens.space12),
            Row(
              children: [
                AppIconBadge(
                  size: AppDimens.iconBadgeSmall,
                  color: color,
                  icon: fact.svg == null
                      ? Icon(fact.fallback)
                      : SvgPicture.asset(
                          fact.svg!,
                          width: AppDimens.iconXs,
                          height: AppDimens.iconXs,
                          colorFilter: ColorFilter.mode(glyph, BlendMode.srcIn),
                          placeholderBuilder: (_) => Icon(fact.fallback),
                        ),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(child: Text(fact.text, style: context.text.bodyLarge)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
