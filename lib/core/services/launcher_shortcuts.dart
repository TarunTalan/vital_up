import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

/// Long-press the app icon: Start workout, Scan food, Water. Each opens
/// its page above Home like a widget tap (after sign-in and start-up when
/// the app was closed). Icons are Android drawables
/// (`res/drawable/shortcut_*.xml`: the widget glyph on the tracker's
/// accent, kept from resource shrinking by `res/raw/keep.xml`).
abstract final class LauncherShortcuts {
  /// Shortcut type = the route it opens ([HomeWidgetService.routeOf]).
  /// Icons are Android drawable names (iOS has no such images: none).
  static List<ShortcutItem> get _items {
    String? icon(String name) => Platform.isAndroid ? name : null;
    return [
      ShortcutItem(
        type: 'activity-tracking',
        localizedTitle: 'Start workout',
        icon: icon('shortcut_workout'),
      ),
      ShortcutItem(
        type: 'food-scan',
        localizedTitle: 'Scan food',
        icon: icon('shortcut_scan'),
      ),
      ShortcutItem(
        type: 'water-trends',
        localizedTitle: 'Water',
        icon: icon('shortcut_water'),
      ),
    ];
  }

  /// Call once at start-up; a shortcut that launched the app is delivered
  /// right after.
  static Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      const actions = QuickActions();
      await actions.initialize(
        (type) => HomeWidgetService.openWhenReady(
          HomeWidgetService.routeOf(Uri(queryParameters: {'route': type})),
        ),
      );
      await actions.setShortcutItems(_items);
    } catch (e) {
      debugPrint('Launcher shortcuts unavailable: $e');
    }
  }
}
