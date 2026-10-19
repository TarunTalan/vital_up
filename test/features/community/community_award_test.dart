import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/presentation/widgets/award_celebration.dart';
import 'package:vital_up/features/community/presentation/widgets/award_widgets.dart';
import 'package:vital_up/features/gamification/data/repositories/gamification_repository_impl.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';
import 'package:vital_up/features/notifications/presentation/widgets/notification_widgets.dart';

CommunityAward _award({
  int id = 1,
  CommunityType type = CommunityType.global,
  AwardPeriod period = AwardPeriod.month,
  DateTime? start,
  int place = 1,
}) => CommunityAward(
  id: id,
  communityId: type.name,
  communityName: type == CommunityType.global ? 'Global' : 'Delhi',
  communityType: type,
  period: period,
  periodStart: start ?? DateTime(2026, 9),
  place: place,
  points: 100,
  players: 10,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('prestige', () {
    test('global monthly, then local monthly, then interest, then weekly', () {
      final ordered = [
        awardPrestige(AwardPeriod.month, CommunityType.global, 3),
        awardPrestige(AwardPeriod.month, CommunityType.local, 1),
        awardPrestige(AwardPeriod.month, CommunityType.interest, 1),
        awardPrestige(AwardPeriod.week, CommunityType.global, 1),
        awardPrestige(AwardPeriod.week, CommunityType.local, 1),
        awardPrestige(AwardPeriod.week, CommunityType.interest, 1),
      ];
      expect(ordered, [...ordered]..sort());
      expect(ordered.toSet(), hasLength(ordered.length));
    });

    test('place breaks ties within the same kind of award', () {
      expect(
        awardPrestige(AwardPeriod.week, CommunityType.local, 1),
        lessThan(awardPrestige(AwardPeriod.week, CommunityType.local, 2)),
      );
    });

    test('sortByPrestige puts the global trophy first, newest on ties', () {
      final weekly = _award(id: 1, period: AwardPeriod.week);
      final localTrophy = _award(id: 2, type: CommunityType.local);
      final globalOld = _award(id: 3, start: DateTime(2026, 7));
      final globalNew = _award(id: 4, start: DateTime(2026, 8));
      expect(
        sortByPrestige([
          weekly,
          localTrophy,
          globalOld,
          globalNew,
        ]).map((a) => a.id),
        [4, 3, 2, 1],
      );
    });
  });

  test('icons: trophies for months, medals for weeks', () {
    expect(AwardIcons.forPlace(AwardPeriod.month, 1), AwardIcons.trophy);
    expect(AwardIcons.forPlace(AwardPeriod.month, 3), AwardIcons.starTrophy);
    expect(AwardIcons.forPlace(AwardPeriod.week, 1), AwardIcons.gold);
    expect(AwardIcons.forPlace(AwardPeriod.week, 2), AwardIcons.silver);
    expect(AwardIcons.forPlace(AwardPeriod.week, 3), AwardIcons.bronze);
  });

  test('award icons ship with the app', () async {
    for (final asset in [
      AwardIcons.trophy,
      AwardIcons.starTrophy,
      AwardIcons.gold,
      AwardIcons.silver,
      AwardIcons.bronze,
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  test('labels', () {
    expect(awardPlaceLabel(2), '2nd');
    expect(
      awardPeriodLabel(AwardPeriod.month, DateTime(2026, 9)),
      'September 2026',
    );
    expect(
      awardPeriodLabel(AwardPeriod.week, DateTime(2026, 10, 5)),
      'Week of 5 Oct',
    );
    expect(_award(type: CommunityType.local, place: 3).title, '3rd in Delhi');
  });

  test('tally counts trophies and each medal', () {
    final tally = AwardTally.of([
      _award(),
      _award(place: 3),
      _award(period: AwardPeriod.week),
      _award(period: AwardPeriod.week, place: 2),
      _award(period: AwardPeriod.week, place: 3),
      _award(period: AwardPeriod.week, place: 3),
    ]);
    expect(tally, const AwardTally(trophies: 2, gold: 1, silver: 1, bronze: 2));
    expect(tally.medals, 4);
  });

  test('parses server rows', () {
    final award = CommunityAward.fromJson({
      'id': 7,
      'community_id': 'c1',
      'community_name': 'Delhi',
      'community_type': 'local',
      'period': 'month',
      'period_start': '2026-09-01',
      'place': 2,
      'points': 640,
      'players': 31,
    });
    expect(award.communityType, CommunityType.local);
    expect(award.isTrophy, isTrue);
    expect(award.periodStart, DateTime(2026, 9));

    final winner = AwardWinner.fromJson({
      'place': 1,
      'user_id': 'u1',
      'username': 'asha',
      'points': 900,
      'level': 6,
      'players': 31,
      'period_start': '2026-10-05',
      'is_me': true,
    });
    expect(winner.isMe, isTrue);
    expect(winner.periodStart, DateTime(2026, 10, 5));
  });

  group('awardToCelebrate', () {
    final now = DateTime(2026, 10, 7);

    test('picks the most important new trophy', () {
      final picked = awardToCelebrate(
        [
          _award(id: 5, type: CommunityType.local),
          _award(id: 6, place: 2),
          _award(id: 7, period: AwardPeriod.week),
        ],
        seenId: 0,
        now: now,
      );
      expect(picked?.id, 6);
    });

    test('skips seen awards, weekly medals and old months', () {
      expect(awardToCelebrate([_award(id: 3)], seenId: 3, now: now), isNull);
      expect(
        awardToCelebrate(
          [_award(id: 9, period: AwardPeriod.week)],
          seenId: 0,
          now: now,
        ),
        isNull,
      );
      expect(
        awardToCelebrate(
          [_award(id: 9, start: DateTime(2026, 8))],
          seenId: 0,
          now: now,
        ),
        isNull,
      );
    });
  });

  group('nextAwardCountdown', () {
    // India is UTC+5:30: 18:30 UTC is midnight there.
    DateTime ist(int y, int m, int d, [int h = 0, int min = 0]) =>
        DateTime.utc(y, m, d, h, min).subtract(AwardRules.serverOffset);

    test('mid-week counts down to the Thursday after the week', () {
      // Thursday 15 Oct 2026, noon India time.
      final next = nextAwardCountdown(AwardPeriod.week, ist(2026, 10, 15, 12));
      expect(next.ended, isFalse);
      expect(next.periodStart, DateTime(2026, 10, 12));
      expect(next.announcesAt, ist(2026, 10, 22, 0, 5));
    });

    test('Monday to Wednesday wait for last week, late logs still count', () {
      final now = ist(2026, 10, 21, 9);
      final next = nextAwardCountdown(AwardPeriod.week, now);
      expect(next.ended, isTrue);
      expect(next.periodStart, DateTime(2026, 10, 12));
      expect(next.announcesAt, ist(2026, 10, 22, 0, 5));
      expect(
        awardCountdownMessage(next, now),
        "Last week's medals in 15h 5m. Late logs still count.",
      );
    });

    test('just after the announcement moves on to the current week', () {
      final next = nextAwardCountdown(
        AwardPeriod.week,
        ist(2026, 10, 22, 0, 6),
      );
      expect(next.ended, isFalse);
      expect(next.periodStart, DateTime(2026, 10, 19));
    });

    test('months announce on the 4th, across the year end', () {
      final dec = nextAwardCountdown(AwardPeriod.month, ist(2026, 12, 10));
      expect(dec.periodStart, DateTime(2026, 12));
      expect(dec.announcesAt, ist(2027, 1, 4, 0, 5));

      final jan3 = nextAwardCountdown(AwardPeriod.month, ist(2027, 1, 3, 23));
      expect(jan3.ended, isTrue);
      expect(jan3.periodStart, DateTime(2026, 12));
    });

    test('India date wins over the UTC date', () {
      // 20:00 UTC Sunday is already Monday 01:30 in India.
      final next = nextAwardCountdown(
        AwardPeriod.week,
        DateTime.utc(2026, 10, 18, 20),
      );
      expect(next.ended, isTrue);
      expect(next.periodStart, DateTime(2026, 10, 12));
    });

    test('formats the time left', () {
      expect(formatAwardCountdown(const Duration(days: 3, hours: 4)), '3d 4h');
      expect(formatAwardCountdown(const Duration(days: 2)), '2d');
      expect(
        formatAwardCountdown(const Duration(hours: 5, minutes: 20)),
        '5h 20m',
      );
      expect(formatAwardCountdown(const Duration(minutes: 12)), '12m');
      expect(formatAwardCountdown(const Duration(seconds: 20)), 'a moment');
    });

    test('says when results are being announced', () {
      final now = ist(2026, 10, 21, 0, 5);
      final due = AwardCountdown(
        period: AwardPeriod.month,
        periodStart: DateTime(2026, 9),
        announcesAt: now,
        ended: true,
      );
      expect(
        awardCountdownMessage(due, now),
        "Last month's trophies are being announced",
      );
    });
  });

  test('rules match the migration', () {
    final sql = File(
      'supabase/migrations/20261019_community_awards.sql',
    ).readAsStringSync();
    expect(
      sql,
      contains('v_min_players CONSTANT INTEGER := ${AwardRules.minPlayers};'),
    );
    // The cutoff moved one day later with the wider report window.
    final cutoff = File(
      'supabase/migrations/20261023_per_user_days.sql',
    ).readAsStringSync();
    expect(
      cutoff,
      contains(
        'v_cutoff DATE := gamification_today() - ${AwardRules.lateDays};',
      ),
    );
    expect(
      cutoff,
      contains(
        'p_day < v_today - ${GamificationRepositoryImpl.maxBackfillDays}',
      ),
    );
    // :35 UTC is :05 India time.
    expect(sql, contains("'35 * * * *'"));
    expect(AwardRules.announceMinute, 5);
  });

  test('award notifications open badges', () {
    expect(NotificationType.fromCode('award'), NotificationType.award);
    expect(NotificationType.award.isAchievement, isTrue);
    expect(notificationRoute(NotificationType.award, null), 'badges');
  });
}
