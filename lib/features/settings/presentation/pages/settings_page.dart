import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsCubit>().loadSettings();
    });
  }

  Widget _buildGlassCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8))
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    final customColors = theme.extension<VitalUpColors>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 12.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.7,
          color: customColors?.grayText ?? const Color(0xFF777777),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey.withValues(alpha: 0.1),
      height: 1,
      thickness: 1,
      indent: 48,
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final vColors = theme.extension<VitalUpColors>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: vColors?.grayText ?? Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vColors = theme.extension<VitalUpColors>();

    return AuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: BackIcon(onClick: () => Navigator.of(context).pop()),
            ),
          ),
          leadingWidth: 56,
          title: Text(
            'Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: BlocConsumer<SettingsCubit, SettingsState>(
          listener: (context, state) {
            if (state is SettingsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.hPadding,
                  vertical: 10,
                ),
                children: [
                          _buildSectionHeader(theme, 'Preferences'),
                          _buildGlassCard(
                            context: context,
                            children: [
                              _buildSettingRow(
                                icon: Icons.palette_rounded,
                                title: 'Theme Mode',
                                subtitle: 'System, Light, or Dark theme',
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: settings.themeMode,
                                      isDense: true,
                                      borderRadius: BorderRadius.circular(12),
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.w600,
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
                                trailing: ToggleButtons(
                                  borderRadius: BorderRadius.circular(8),
                                  constraints: const BoxConstraints(
                                    minHeight: 28,
                                    minWidth: 46,
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
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
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('cm'),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('in'),
                                    ),
                                  ],
                                ),
                              ),
                              _buildDivider(),
                              _buildSettingRow(
                                icon: Icons.monitor_weight_rounded,
                                title: 'Weight Unit',
                                subtitle: 'Kilograms or Pounds',
                                trailing: ToggleButtons(
                                  borderRadius: BorderRadius.circular(8),
                                  constraints: const BoxConstraints(
                                    minHeight: 28,
                                    minWidth: 46,
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
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
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('kg'),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('lbs'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _buildSectionHeader(theme, 'Alerts & Integrations'),
                          _buildGlassCard(
                            context: context,
                            children: [
                              _buildSettingRow(
                                icon: Icons.notifications_active_rounded,
                                title: 'Notifications',
                                subtitle: 'Daily check-in and log reminders',
                                trailing: Transform.scale(
                                  scale: 0.75,
                                  child: Switch(
                                    value: settings.notificationsEnabled,
                                    onChanged: (val) {
                                      context.read<SettingsCubit>().updateSettings(
                                            settings.copyWith(notificationsEnabled: val),
                                          );
                                    },
                                  ),
                                ),
                              ),
                              _buildDivider(),
                              _buildSettingRow(
                                icon: Icons.sync_rounded,
                                title: 'Health Sync',
                                subtitle: 'Google Fit / Health Connect integration',
                                trailing: Transform.scale(
                                  scale: 0.75,
                                  child: Switch(
                                    value: settings.healthSyncEnabled,
                                    onChanged: (val) {
                                      context.read<SettingsCubit>().updateSettings(
                                            settings.copyWith(healthSyncEnabled: val),
                                          );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSectionHeader(theme, 'Info'),
                          _buildGlassCard(
                            context: context,
                            children: [
                              _buildSettingRow(
                                icon: Icons.info_outline_rounded,
                                title: 'Version',
                                subtitle: 'VitalUp v1.0.0 (Production)',
                              ),
                            ],
                          ),
                ],
              );
            }

            return const Center(child: Text('Settings not found'));
          },
        ),
      ),
    );
  }
}
