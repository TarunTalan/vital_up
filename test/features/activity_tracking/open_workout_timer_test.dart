import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_timer_page.dart';

/// The timer notification opens the timer screen without stacking copies,
/// so Back goes to where the user was.
void main() {
  late GoRouter router;
  late BuildContext home;

  Widget page(String label) => Scaffold(body: Text(label));

  Future<void> pumpRouter(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, _) {
            home = context;
            return page('Home');
          },
        ),
        GoRoute(
          path: '/activity-tracking',
          name: 'activity-tracking',
          builder: (_, _) => page('Tracking'),
        ),
        GoRoute(
          path: '/workout-timer',
          name: 'workout-timer',
          builder: (_, _) => page('Timer'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  List<String?> stack() => router.routerDelegate.currentConfiguration.matches
      .map((m) => (m.route as GoRoute).name)
      .toList();

  testWidgets('opens the timer above the current page', (tester) async {
    await pumpRouter(tester);
    router.pushNamed('activity-tracking');
    await tester.pumpAndSettle();

    openWorkoutTimer(home);
    await tester.pumpAndSettle();
    expect(stack(), ['dashboard', 'activity-tracking', 'workout-timer']);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Tracking'), findsOneWidget);
  });

  testWidgets('a timer already open is not opened again', (tester) async {
    await pumpRouter(tester);
    router.pushNamed('workout-timer');
    await tester.pumpAndSettle();

    openWorkoutTimer(home);
    await tester.pumpAndSettle();
    expect(stack(), ['dashboard', 'workout-timer']);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('pages above an open timer close', (tester) async {
    await pumpRouter(tester);
    router.pushNamed('workout-timer');
    await tester.pumpAndSettle();
    router.pushNamed('activity-tracking');
    await tester.pumpAndSettle();

    openWorkoutTimer(home);
    await tester.pumpAndSettle();
    expect(stack(), ['dashboard', 'workout-timer']);
    expect(find.text('Timer'), findsOneWidget);
  });
}
