import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Short-hands for theme lookups so widgets never hardcode colours/styles.
///
/// ```dart
/// Text('Sleep', style: context.text.titleSmall)
/// Container(color: context.vColors.glassFill)
/// ```
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// VitalUp brand tokens. Falls back to the light set if the extension is
  /// missing (e.g. in isolated widget tests).
  VitalUpColors get vColors =>
      Theme.of(this).extension<VitalUpColors>() ??
      (isDark ? AppTheme.darkCustomColors : AppTheme.lightCustomColors);
}
