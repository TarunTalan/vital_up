import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/router/route_extras.dart';

class _Community {
  final String id;
  _Community(this.id);
}

void main() {
  // go_router rebuilds a pushed page without its `extra` once it runs its
  // redirects again (on the phone: switching light / dark mode while a
  // leaderboard is open showed "This page isn't available").
  testWidgets('a pushed page keeps its extra when redirects run again', (
    tester,
  ) async {
    String shown(GoRouterState s) {
      final extra = routeExtra(s);
      return extra is _Community ? 'Board ${extra.id}' : 'Unavailable';
    }

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => c.push('/community/x', extra: _Community('x')),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/community/:id',
          redirect: (_, s) => routeExtra(s) is _Community ? null : '/home',
          builder: (_, s) => Scaffold(body: Text(shown(s))),
        ),
      ],
    );
    addTearDown(router.dispose);
    final mode = ValueNotifier(ThemeMode.light);
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: mode,
        builder: (_, m, _) => MaterialApp.router(
          routerConfig: router,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: m,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Board x'), findsOneWidget);

    mode.value = ThemeMode.dark;
    router.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Board x'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
  });
}
