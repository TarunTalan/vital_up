import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/presentation/widgets/badge_widgets.dart';

void main() {
  final earned = GameBadge(
    code: 'streak_7',
    name: 'Week Warrior',
    description: 'Keep a 7 day streak',
    iconKey: 'streak_7',
    bonusPoints: 50,
    threshold: 7,
    progress: 7,
    earnedAt: DateTime(2026, 10, 10),
  );

  const locked = GameBadge(
    code: 'steps_20k',
    name: 'Marathon Walker',
    description: 'Hit 20,000 steps in a single day',
    iconKey: 'steps_20k',
    bonusPoints: 100,
    threshold: 20000,
    progress: 12500,
  );

  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 180, height: 200, child: child),
      ),
    ),
  );

  test('progress label only for locked badges with progress', () {
    expect(badgeProgressLabel(locked), '12,500 of 20,000');
    expect(badgeProgressLabel(earned), isNull);
    expect(badgeEarnedLabel(earned), 'Earned Oct 10, 2026');
  });

  testWidgets('earned tile shows the earned date', (tester) async {
    await tester.pumpWidget(host(BadgeTile(badge: earned)));
    expect(find.text('Week Warrior'), findsOneWidget);
    expect(find.text('Earned Oct 10, 2026'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('locked tile shows progress', (tester) async {
    await tester.pumpWidget(host(const BadgeTile(badge: locked)));
    expect(find.text('12,500 of 20,000'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('tapping a tile opens the detail sheet', (tester) async {
    await tester.pumpWidget(host(const BadgeTile(badge: locked)));
    await tester.tap(find.byType(BadgeTile));
    await tester.pumpAndSettle();

    expect(find.byType(BadgeDetailSheet), findsOneWidget);
    expect(find.text('Hit 20,000 steps in a single day'), findsOneWidget);
    expect(find.text('Your progress'), findsOneWidget);
    expect(find.text('63%'), findsOneWidget);
    expect(find.text('12,500 of 20,000 · 7,500 to go'), findsOneWidget);
    expect(find.text('+100 pts'), findsOneWidget);
    expect(find.text('Bonus when earned'), findsOneWidget);
  });

  testWidgets('earned detail sheet skips the progress card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: BadgeDetailSheet(badge: earned)),
      ),
    );
    expect(find.text('Your progress'), findsNothing);
    expect(find.text('Earned Oct 10, 2026'), findsOneWidget);
    expect(find.text('Bonus points added'), findsOneWidget);
  });
}
