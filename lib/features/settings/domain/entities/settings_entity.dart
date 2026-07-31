import 'package:equatable/equatable.dart';

class SettingsEntity extends Equatable {
  final String themeMode;
  final bool notificationsEnabled;
  final bool healthSyncEnabled;
  final String weightUnit;
  final String heightUnit;

  const SettingsEntity({
    this.themeMode = 'system',
    this.notificationsEnabled = true,
    this.healthSyncEnabled = false,
    this.weightUnit = 'kg',
    this.heightUnit = 'cm',
  });

  SettingsEntity copyWith({
    String? themeMode,
    bool? notificationsEnabled,
    bool? healthSyncEnabled,
    String? weightUnit,
    String? heightUnit,
  }) {
    return SettingsEntity(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      healthSyncEnabled: healthSyncEnabled ?? this.healthSyncEnabled,
      weightUnit: weightUnit ?? this.weightUnit,
      heightUnit: heightUnit ?? this.heightUnit,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        notificationsEnabled,
        healthSyncEnabled,
        weightUnit,
        heightUnit,
      ];
}
