import 'package:equatable/equatable.dart';

class SettingsEntity extends Equatable {
  final String themeMode;
  final bool notificationsEnabled;
  final bool healthSyncEnabled;
  final String weightUnit;
  final String heightUnit;

  /// Firebase Analytics (app opens and screens; never health data).
  final bool analyticsEnabled;

  const SettingsEntity({
    this.themeMode = 'system',
    this.notificationsEnabled = true,
    this.healthSyncEnabled = false,
    this.weightUnit = 'kg',
    // Feet and inches unless the user picks cm in Settings.
    this.heightUnit = 'in',
    this.analyticsEnabled = true,
  });

  SettingsEntity copyWith({
    String? themeMode,
    bool? notificationsEnabled,
    bool? healthSyncEnabled,
    String? weightUnit,
    String? heightUnit,
    bool? analyticsEnabled,
  }) {
    return SettingsEntity(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      healthSyncEnabled: healthSyncEnabled ?? this.healthSyncEnabled,
      weightUnit: weightUnit ?? this.weightUnit,
      heightUnit: heightUnit ?? this.heightUnit,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    notificationsEnabled,
    healthSyncEnabled,
    weightUnit,
    heightUnit,
    analyticsEnabled,
  ];
}
