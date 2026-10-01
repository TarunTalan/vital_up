import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/router/app_router.dart';
import 'package:vital_up/features/notifications/presentation/widgets/notification_widgets.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/domain/reminder_presets.dart';
import 'package:vital_up/features/reminders/presentation/widgets/reminder_style.dart';

/// Smoke test: every route a notification or reminder can open exists, so
/// a tap never lands on go_router's error page.
void main() {
  final router = AppRouter.router;

  bool exists(String name) {
    try {
      router.namedLocation(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  test('notification links point at real routes', () {
    for (final name in notificationLinkableRoutes) {
      expect(exists(name), isTrue, reason: 'missing route "$name"');
    }
  });

  test('reminder targets are real, linkable routes', () {
    final routes = {
      for (final kind in ReminderKind.values) ?kind.defaultRoute,
      for (final preset in reminderPresets) ?preset.route,
      for (final target in reminderTargets) ?target.$2,
    };
    for (final name in routes) {
      expect(exists(name), isTrue, reason: 'missing route "$name"');
      expect(
        notificationLinkableRoutes,
        contains(name),
        reason: 'a tapped reminder could not open "$name"',
      );
    }
  });
}
