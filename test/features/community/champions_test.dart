import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/community/presentation/widgets/award_widgets.dart';

import '../../helpers/pump_app.dart';

const _global = Community(
  id: 'g',
  slug: 'global',
  name: 'Global',
  type: CommunityType.global,
  iconKey: 'global',
);
const _city = Community(
  id: 'c',
  slug: 'bengaluru',
  name: 'Bengaluru',
  type: CommunityType.local,
  iconKey: 'city',
);

List<AwardWinner> _winners(DateTime start, {bool meSecond = false}) => [
  for (var place = 1; place <= 3; place++)
    AwardWinner(
      place: place,
      userId: 'u$place',
      username: 'runner_number_$place',
      points: 1000 - place * 100,
      level: 12,
      periodStart: start,
      isMe: meSecond && place == 2,
    ),
];

void main() {
  final week = DateTime(2026, 10, 12);
  final month = DateTime(2026, 9, 1);

  group('latestChampionsPeriod', () {
    test('a week announced after the month opens first', () {
      expect(
        latestChampionsPeriod([
          CommunityWinners(
            community: _global,
            period: AwardPeriod.month,
            winners: _winners(month),
          ),
          CommunityWinners(
            community: _global,
            period: AwardPeriod.week,
            winners: _winners(week),
          ),
        ]),
        AwardPeriod.week,
      );
    });

    test('new trophies open first in the days after they land', () {
      // September's trophies land 3 Oct; the week of 21 Sep on 1 Oct.
      expect(
        latestChampionsPeriod([
          CommunityWinners(
            community: _global,
            period: AwardPeriod.month,
            winners: _winners(month),
          ),
          CommunityWinners(
            community: _city,
            period: AwardPeriod.week,
            winners: _winners(DateTime(2026, 9, 21)),
          ),
        ]),
        AwardPeriod.month,
      );
    });

    test('no winners: none', () {
      expect(
        latestChampionsPeriod([
          const CommunityWinners(
            community: _global,
            period: AwardPeriod.week,
            winners: [],
          ),
        ]),
        isNull,
      );
    });

    test('announcement time matches the countdown rule', () {
      // Week of Mon 12 Oct ends Mon 19; +3 days, 00:05 India = 18:35 UTC.
      expect(
        awardAnnouncedAt(AwardPeriod.week, week),
        DateTime.utc(2026, 10, 21, 18, 35),
      );
    });
  });

  group('PlayerProfile.fromJson', () {
    test('friend flag, and older servers answered friends only', () {
      final base = {'user_id': 'u1', 'username': 'a', 'level': 3};
      expect(PlayerProfile.fromJson(base).isFriend, isTrue);
      expect(
        PlayerProfile.fromJson({...base, 'friend': false}).isFriend,
        isFalse,
      );
    });
  });

  group('ChampionsCard', () {
    final champions = [
      CommunityWinners(
        community: _global,
        period: AwardPeriod.week,
        winners: _winners(week, meSecond: true),
      ),
      CommunityWinners(
        community: _city,
        period: AwardPeriod.week,
        winners: _winners(week),
      ),
      CommunityWinners(
        community: _global,
        period: AwardPeriod.month,
        winners: _winners(month),
      ),
    ];

    for (final (scale, dark) in [(1.0, false), (kMaxTextScale, true)]) {
      testWidgets('one row per community at text $scale', (tester) async {
        Community? opened;
        await pumpPage(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ChampionsCard(
                champions: champions,
                onOpenCommunity: (c) => opened = c,
              ),
            ),
          ),
          textScale: scale,
          theme: dark ? AppTheme.darkTheme : null,
        );
        await tester.pump();
        expect(find.text('Champions'), findsOneWidget);
        expect(find.text('Last week'), findsOneWidget);
        expect(find.text('Everyone on VitalUp'), findsOneWidget);
        expect(find.text('Bengaluru'), findsOneWidget);
        // The winner, and your own place when you placed.
        expect(
          find.text('1st @runner_number_1 · 900 pts · You 2nd'),
          findsOneWidget,
        );
        expect(find.text('1st @runner_number_1 · 900 pts'), findsOneWidget);
        // Not every winner: that's the leaderboard's job.
        expect(find.textContaining('runner_number_3'), findsNothing);
        expect(takeAllExceptions(tester), isEmpty);
        expect(truncatedTexts(tester), isEmpty);

        await tester.tap(find.text('Everyone on VitalUp'));
        expect(opened?.id, 'g');

        await tester.tap(find.text('Last month'));
        await tester.pump();
        expect(find.text('Bengaluru'), findsNothing);
        expect(truncatedTexts(tester), isEmpty);
      });
    }
  });

  for (final (scale, dark) in [(1.0, false), (kMaxTextScale, true)]) {
    testWidgets('How awards work fits at text $scale', (tester) async {
      await pumpPage(
        tester,
        const Scaffold(body: AwardRulesSheet()),
        textScale: scale,
        theme: dark ? AppTheme.darkTheme : null,
      );
      await tester.pump();
      expect(find.text('How awards work'), findsOneWidget);
      for (final title in [
        'Weekly medals',
        'Monthly trophies',
        'Who can win',
        'Where they show',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  }
}
