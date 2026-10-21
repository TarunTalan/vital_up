import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

/// Long-press the app icon: Start workout, Scan food, Water. Each opens
/// its page above Home like a widget tap (after sign-in and start-up when
/// the app was closed). No icons yet: Android shows the app icon beside
/// each one until shortcut icons are added to `res/drawable`.
abstract final class LauncherShortcuts {
  /// Shortcut type = the route it opens ([HomeWidgetService.routeOf]).
  static const _items = [
    ShortcutItem(type: 'activity-tracking', localizedTitle: 'Start workout'),
    ShortcutItem(type: 'food-scan', localizedTitle: 'Scan food'),
    ShortcutItem(type: 'water-trends', localizedTitle: 'Water'),
  ];

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
