import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

void main() {
  testWidgets('an icon not supplied yet shows its fallback without loading', (
    tester,
  ) async {
    await tester.runAsync(BundledAssets.preload);
    expect(BundledAssets.has(GamificationIcons.crown), isTrue);
    expect(BundledAssets.has('assets/icons/communities/global.svg'), isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            GameIcon(
              GamificationIcons.communityIcon('global'),
              fallback: Icons.public_rounded,
              size: 24,
            ),
            const GameIcon(
              GamificationIcons.crown,
              fallback: Icons.workspace_premium_rounded,
              size: 24,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
