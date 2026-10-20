import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_colors.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

void main() {
  const backdrops = {
    'light': AppColors.cardBackdropLight,
    'dark': AppColors.cardBackdropDark,
  };

  for (final MapEntry(key: theme, value: bg) in backdrops.entries) {
    test('every tracker accent reaches 3:1 as an icon on $theme cards', () {
      for (final m in TrackerMetric.values) {
        final tint = AppColors.readableOn(m.color, bg);
        expect(
          _contrast(tint, bg),
          greaterThanOrEqualTo(AppColors.iconContrast),
          reason: '${m.label} on $theme',
        );
      }
    });
  }

  for (final MapEntry(key: theme, value: bg) in backdrops.entries) {
    test('badge glyphs reach 3:1 on their tinted circle on $theme cards', () {
      for (final m in TrackerMetric.values) {
        final circle = Color.alphaBlend(m.color.withValues(alpha: 0.2), bg);
        final glyph = AppColors.readableOn(m.color, circle);
        expect(
          _contrast(glyph, circle),
          greaterThanOrEqualTo(AppColors.iconContrast),
          reason: '${m.label} badge on $theme',
        );
      }
    });
  }

  test('keeps the hue and leaves readable colours alone', () {
    const deep = Color(0xFF1A237E);
    expect(AppColors.readableOn(deep, AppColors.cardBackdropLight), deep);
    final cyan = AppColors.readableOn(
      AppColors.primary,
      AppColors.cardBackdropLight,
    );
    expect(
      HSLColor.fromColor(cyan).hue,
      closeTo(HSLColor.fromColor(AppColors.primary).hue, 1),
    );
  });
}
