import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/presentation/widgets/flip_badge_card.dart';

void main() {
  const earnedBadge = GameBadge(
    code: 'streak_7',
    name: 'Week Warrior',
    description: 'Maintain a 7-day workout streak',
    iconKey: 'streak_7',
    bonusPoints: 50,
    threshold: 7,
    progress: 7,
  );

  final earnedBadgeWithDate = GameBadge(
    code: 'streak_7',
    name: 'Week Warrior',
    description: 'Maintain a 7-day workout streak',
    iconKey: 'streak_7',
    bonusPoints: 50,
    threshold: 7,
    progress: 7,
    earnedAt: DateTime(2026, 10, 10),
  );

  const lockedBadge = GameBadge(
    code: 'steps_20k',
    name: 'Marathon Walker',
    description: 'Hit 20,000 steps in a single day',
    iconKey: 'steps_20k',
    bonusPoints: 100,
    threshold: 20000,
    progress: 12500,
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 140,
            height: 200,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('FlipBadgeCard displays front face initially', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const FlipBadgeCard(badge: earnedBadge),
      ),
    );
    await tester.pumpAndSettle();

    // Front content should be visible
    expect(find.text('Week Warrior'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('GOAL'), findsNothing);
  });

  testWidgets('FlipBadgeCard flips to back on tap and shows goal', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        FlipBadgeCard(badge: earnedBadgeWithDate),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EARNED'), findsOneWidget);
    expect(find.text('GOAL'), findsNothing);

    // Tap to flip
    await tester.tap(find.byType(FlipBadgeCard));
    await tester.pumpAndSettle();

    // Back content should now be visible
    expect(find.text('GOAL'), findsOneWidget);
    expect(find.text('Maintain a 7-day workout streak'), findsOneWidget);
    expect(find.textContaining('Achieved'), findsNothing);
    expect(find.textContaining('Oct 10, 2026'), findsOneWidget);
    expect(find.text('Tap to flip back'), findsOneWidget);

    // Tap again to flip back to front
    await tester.tap(find.byType(FlipBadgeCard));
    await tester.pumpAndSettle();

    expect(find.text('GOAL'), findsNothing);
    expect(find.text('EARNED'), findsOneWidget);
  });

  testWidgets('FlipBadgeCard displays progress for locked badge', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const FlipBadgeCard(badge: lockedBadge),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('12,500 of 20,000'), findsOneWidget);

    // Flip to back
    await tester.tap(find.byType(FlipBadgeCard));
    await tester.pumpAndSettle();

    expect(find.text('GOAL'), findsOneWidget);
    expect(find.text('Hit 20,000 steps in a single day'), findsOneWidget);
    expect(find.text('Progress: 12,500 of 20,000'), findsOneWidget);
  });

  testWidgets('showBadgeGoalDialog displays dialog with flippable badge card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBadgeGoalDialog(context, lockedBadge),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(FlipBadgeCard), findsOneWidget);
    expect(find.text('Marathon Walker'), findsOneWidget);

    // Flip in dialog
    await tester.tap(find.byType(FlipBadgeCard));
    await tester.pumpAndSettle();

    expect(find.text('GOAL'), findsOneWidget);
    expect(find.text('Hit 20,000 steps in a single day'), findsOneWidget);

    // Close dialog
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(FlipBadgeCard), findsNothing);
  });
}
