import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/account/data/data_export_service.dart';
import 'package:vital_up/features/account/presentation/delete_account_sheet.dart';
import 'package:vital_up/features/health_sync/health_import_service.dart';
import 'package:vital_up/core/services/biometric_auth_service.dart';
import 'package:vital_up/features/help_support/domain/entities/support_ticket.dart';
import 'package:vital_up/features/help_support/presentation/pages/contact_support_page.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _packageInfo = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsCubit>().loadSettings();
    });
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCaption(title),
          const SizedBox(height: AppDimens.space8),
          AppCard(
            width: double.infinity,
            padding: AppDimens.cardPaddingCompact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: context.vColors.divider,
      height: AppDimens.borderThin,
      thickness: AppDimens.borderThin,
      indent: AppDimens.iconBadge + AppDimens.space12,
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
      child: Row(
        children: [
          AppIconBadge(icon: Icon(icon), color: iconColor),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: AppDimens.space2),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppDimens.space8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildUnitToggle({
    required List<String> labels,
    required List<bool> isSelected,
    required ValueChanged<int> onPressed,
  }) {
    final colors = context.colors;
    final v = context.vColors;
    return ToggleButtons(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      constraints: const BoxConstraints(
        minHeight: AppDimens.space32,
        minWidth: AppDimens.space40,
      ),
      textStyle: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      color: v.grayText,
      selectedColor: v.buttonText,
      fillColor: colors.primary,
      borderColor: v.glassBorder,
      selectedBorderColor: colors.primary,
      isSelected: isSelected,
      onPressed: onPressed,
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.space12),
            child: Text(label),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return AppScaffold(
      header: const AppPageHeader(title: 'Settings'),
      scrollable: false,
      padBody: false,
      body: BlocConsumer<SettingsCubit, SettingsState>(
        listener: (context, state) {
          if (state is SettingsError) {
            showErrorSnackBar(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is SettingsLoading || state is SettingsInitial) {
            return const Center(child: VitalUpLoader());
          }

          if (state is SettingsLoaded) {
            final settings = state.settings;

            return ListView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.sectionGap,
                context.gutter,
                AppDimens.sectionGap + context.safePadding.bottom,
              ),
              children: [
                _buildSection('Preferences', [
                  _buildSettingRow(
                    icon: Icons.palette_rounded,
                    title: 'Theme Mode',
                    subtitle: 'System, Light, or Dark theme',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space8,
                        vertical: AppDimens.space4,
                      ),
                      decoration: BoxDecoration(
                        color: v.primaryFill,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(color: v.primaryBorder!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: settings.themeMode,
                          isDense: true,
                          borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: AppDimens.iconSm,
                          ),
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'system', child: Text('System')),
                            DropdownMenuItem(value: 'light', child: Text('Light')),
                            DropdownMenuItem(value: 'dark', child: Text('Dark')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              context.read<SettingsCubit>().updateSettings(
                                    settings.copyWith(themeMode: val),
                                  );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingRow(
                    icon: Icons.straighten_rounded,
                    title: 'Height Unit',
                    subtitle: 'Centimeters or Inches',
                    trailing: _buildUnitToggle(
                      labels: const ['cm', 'in'],
                      isSelected: [
                        settings.heightUnit == 'cm',
                        settings.heightUnit == 'in',
                      ],
                      onPressed: (index) {
                        context.read<SettingsCubit>().updateSettings(
                              settings.copyWith(
                                heightUnit: index == 0 ? 'cm' : 'in',
                              ),
                            );
                      },
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingRow(
                    icon: Icons.monitor_weight_rounded,
                    title: 'Weight Unit',
                    subtitle: 'Kilograms or Pounds',
                    trailing: _buildUnitToggle(
                      labels: const ['kg', 'lbs'],
                      isSelected: [
                        settings.weightUnit == 'kg',
                        settings.weightUnit == 'lbs',
                      ],
                      onPressed: (index) {
                        context.read<SettingsCubit>().updateSettings(
                              settings.copyWith(
                                weightUnit: index == 0 ? 'kg' : 'lbs',
                              ),
                            );
                      },
                    ),
                  ),
                ]),
                _buildSection('Alerts & Integrations', [
                  _buildSettingRow(
                    icon: Icons.notifications_active_rounded,
                    title: 'Notifications',
                    subtitle: 'Pushes and reminders',
                    trailing: Switch(
                      value: settings.notificationsEnabled,
                      onChanged: (val) {
                        context.read<SettingsCubit>().updateSettings(
                              settings.copyWith(notificationsEnabled: val),
                            );
                      },
                    ),
                  ),
                  _buildDivider(),
                  InkWell(
                    onTap: () => context.pushNamed('reminders'),
                    child: _buildSettingRow(
                      icon: Icons.alarm_rounded,
                      title: 'Reminders',
                      subtitle: 'Activity, meals, water, sleep',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                  _buildDivider(),
                  InkWell(
                    onTap: () => context.pushNamed('home-widgets'),
                    child: _buildSettingRow(
                      icon: Icons.widgets_rounded,
                      title: 'Home Screen Widgets',
                      subtitle: 'Live previews, quick actions & add to home screen',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingRow(
                    icon: Icons.sync_rounded,
                    title: 'Health Sync',
                    subtitle: 'Import weight and workouts from Health Connect / Apple Health',
                    trailing: Switch(
                      value: settings.healthSyncEnabled,
                      onChanged: (val) async {
                        final cubit = context.read<SettingsCubit>();
                        if (val && !await sl<HealthImportService>().connect()) {
                          if (context.mounted) {
                            showErrorSnackBar(
                              context,
                              'Allow VitalUp to read weight and workouts in '
                              'Health Connect / Apple Health to turn this on.',
                            );
                          }
                          return;
                        }
                        cubit.updateSettings(
                          settings.copyWith(healthSyncEnabled: val),
                        );
                      },
                    ),
                  ),
                ]),
                _buildSection('Privacy & Security', [
                  _buildSettingRow(
                    icon: Icons.fingerprint_rounded,
                    iconColor: AppColors.primary,
                    title: 'Biometric App Lock',
                    subtitle: 'Protect health records with Fingerprint / Face ID / PIN',
                    trailing: Switch(
                      value: sl<BiometricAuthService>().isBiometricEnabled(),
                      onChanged: (val) async {
                        final success = await sl<BiometricAuthService>().setBiometricEnabled(val);
                        if (mounted) {
                          setState(() {});
                          if (success) {
                            showSuccessSnackBar(
                              context,
                              val ? 'Biometric App Lock enabled 🔒' : 'Biometric App Lock disabled',
                            );
                          } else if (val) {
                            showErrorSnackBar(
                              context,
                              'Biometric authentication failed or not supported on this device',
                            );
                          }
                        }
                      },
                    ),
                  ),
                  _buildDivider(),
                  InkWell(
                    onTap: () => context.pushNamed('health-report'),
                    child: _buildSettingRow(
                      icon: Icons.medical_services_outlined,
                      iconColor: AppColors.teal,
                      title: 'Doctor Health Report',
                      subtitle: 'Generate clinical summary for your physician',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                ]),
                _buildSection('Account', [
                  InkWell(
                    onTap: () async {
                      final error =
                          await sl<DataExportService>().exportAndShare();
                      if (error != null && context.mounted) {
                        showErrorSnackBar(context, error);
                      }
                    },
                    child: _buildSettingRow(
                      icon: Icons.download_rounded,
                      title: 'Export my data',
                      subtitle: 'Logs, workouts and profile as CSV / JSON',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                  _buildDivider(),
                  InkWell(
                    onTap: () => showDeleteAccountSheet(context),
                    child: _buildSettingRow(
                      icon: Icons.delete_forever_rounded,
                      iconColor: context.colors.error,
                      title: 'Delete account',
                      subtitle: 'Permanently remove your account and data',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                ]),
                _buildSection('Help & Support', [
                  InkWell(
                    onTap: () => context.pushNamed('help-support'),
                    child: _buildSettingRow(
                      icon: Icons.help_outline_rounded,
                      iconColor: AppColors.primary,
                      title: 'Help Center & FAQs',
                      subtitle: 'Answers, guides, and troubleshooting',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                  _buildDivider(),
                  InkWell(
                    onTap: () => context.pushNamed('support-chat'),
                    child: _buildSettingRow(
                      icon: Icons.smart_toy_outlined,
                      iconColor: AppColors.primary,
                      title: 'Vital Assistant',
                      subtitle: 'Instant AI support & diagnostics',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                  _buildDivider(),
                  InkWell(
                    onTap: () => openContactSupport(
                      context,
                      initialCategory: SupportCategory.general,
                    ),
                    child: _buildSettingRow(
                      icon: Icons.mail_outline_rounded,
                      title: 'Contact Support Team',
                      subtitle: 'Email support with category & diagnostics',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                ]),
                _buildSection('Info & About', [
                  InkWell(
                    onTap: () => context.pushNamed('about'),
                    child: _buildSettingRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.primary,
                      title: 'About VitalUp',
                      subtitle: 'Mission, rating, features & creators',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: v.grayText,
                      ),
                    ),
                  ),
                  _buildDivider(),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snap) => _buildSettingRow(
                      icon: Icons.code_rounded,
                      title: 'Version',
                      subtitle: snap.hasData
                          ? 'VitalUp ${snap.data!.version} '
                                '(${snap.data!.buildNumber})'
                          : 'VitalUp',
                    ),
                  ),
                ]),
              ],
            );
          }

          return Center(
            child: Text(
              'Settings not found',
              style: context.text.bodyMedium?.copyWith(color: v.grayText),
            ),
          );
        },
      ),
    );
  }
}
