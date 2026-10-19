import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';

/// A finished leaderboard period that awards its top 3: weekly medals,
/// monthly trophies (`community_awards`, finalised by the server once late
/// reports are closed).
enum AwardPeriod {
  week,
  month;

  static AwardPeriod fromName(String? name) =>
      name == 'month' ? AwardPeriod.month : AwardPeriod.week;
}

/// Award art (`assets/icons/awards/`). Multi-colour: never tint them.
abstract final class AwardIcons {
  static const _dir = 'assets/icons/awards';
  static const trophy = '$_dir/Trophy Cup.svg';
  static const starTrophy = '$_dir/Tropy Star.svg';
  static const gold = '$_dir/Gold Medal.svg';
  static const silver = '$_dir/Silver Medal.svg';
  static const bronze = '$_dir/Bronze Medal.svg';

  /// Monthly: the cup for 1st, the star trophy for 2nd and 3rd. Weekly:
  /// gold, silver, bronze.
  static String forPlace(AwardPeriod period, int place) => switch (period) {
    AwardPeriod.month => place == 1 ? trophy : starTrophy,
    AwardPeriod.week => switch (place) {
      1 => gold,
      2 => silver,
      _ => bronze,
    },
  };
}

/// "1st", "2nd", "3rd".
String awardPlaceLabel(int place) => switch (place) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${place}th',
};

/// "October 2026" for a month, "Week of 5 Oct" for a week.
String awardPeriodLabel(AwardPeriod period, DateTime start) => switch (period) {
  AwardPeriod.month => DateFormat('MMMM y').format(start),
  AwardPeriod.week => 'Week of ${DateFormat('d MMM').format(start)}',
};

/// How much an award counts, lower first: global monthly toppers lead,
/// then local monthly, interest monthly, and weekly medals in the same
/// community order; 1st before 2nd before 3rd.
int awardPrestige(AwardPeriod period, CommunityType type, int place) {
  final scope = switch (type) {
    CommunityType.global => 0,
    CommunityType.local => 1,
    _ => 2,
  };
  return ((period == AwardPeriod.month ? 0 : 3) + scope) * 10 + place;
}

/// Award rules shared with `20261019_community_awards.sql` (cutoff moved
/// in `20261023_per_user_days.sql`); a test keeps them in sync.
abstract final class AwardRules {
  /// Players with points a leaderboard needs that period.
  static const minPlayers = 5;

  /// Days a period stays open for late logs after it ends (the oldest day
  /// `submit_daily_report` still accepts is today - 3).
  static const lateDays = 3;

  /// Scoring days are India days (`gamification_today()`).
  static const serverOffset = Duration(hours: 5, minutes: 30);

  /// The hourly job runs at :05 India time; results land on the first run
  /// of the due day.
  static const announceMinute = 5;
}

/// When one period's winners are announced.
class AwardCountdown extends Equatable {
  final AwardPeriod period;

  /// First day of the period (an India date).
  final DateTime periodStart;

  /// When the results land, in UTC.
  final DateTime announcesAt;

  /// The period is over and waiting for late logs.
  final bool ended;

  const AwardCountdown({
    required this.period,
    required this.periodStart,
    required this.announcesAt,
    required this.ended,
  });

  Duration remaining(DateTime now) {
    final left = announcesAt.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  List<Object?> get props => [period, periodStart, announcesAt, ended];
}

/// The next announcement for [period] at [now]: the period that just ended
/// while late logs are still counted, otherwise the current one.
AwardCountdown nextAwardCountdown(AwardPeriod period, DateTime now) {
  // India wall time, kept in a UTC DateTime so date maths has no DST.
  final local = now.toUtc().add(AwardRules.serverOffset);
  final today = DateTime.utc(local.year, local.month, local.day);
  final current = switch (period) {
    AwardPeriod.week => today.subtract(Duration(days: today.weekday - 1)),
    AwardPeriod.month => DateTime.utc(today.year, today.month),
  };
  final previous = switch (period) {
    AwardPeriod.week => current.subtract(const Duration(days: 7)),
    AwardPeriod.month => DateTime.utc(current.year, current.month - 1),
  };

  DateTime announcement(DateTime start) {
    final end = switch (period) {
      AwardPeriod.week => start.add(const Duration(days: 7)),
      AwardPeriod.month => DateTime.utc(start.year, start.month + 1),
    };
    return DateTime.utc(
      end.year,
      end.month,
      end.day + AwardRules.lateDays,
      0,
      AwardRules.announceMinute,
    ).subtract(AwardRules.serverOffset);
  }

  DateTime asDate(DateTime d) => DateTime(d.year, d.month, d.day);

  final pending = announcement(previous);
  if (now.toUtc().isBefore(pending)) {
    return AwardCountdown(
      period: period,
      periodStart: asDate(previous),
      announcesAt: pending,
      ended: true,
    );
  }
  return AwardCountdown(
    period: period,
    periodStart: asDate(current),
    announcesAt: announcement(current),
    ended: false,
  );
}

/// "3d 4h", "5h 20m", "12m", or "a moment" when due.
String formatAwardCountdown(Duration left) {
  if (left.inMinutes < 1) return 'a moment';
  if (left.inDays >= 1) {
    final h = left.inHours % 24;
    return h == 0 ? '${left.inDays}d' : '${left.inDays}d ${h}h';
  }
  if (left.inHours >= 1) {
    final m = left.inMinutes % 60;
    return m == 0 ? '${left.inHours}h' : '${left.inHours}h ${m}m';
  }
  return '${left.inMinutes}m';
}

/// One award the player won.
class CommunityAward extends Equatable {
  final int id;
  final String communityId;
  final String communityName;
  final CommunityType communityType;
  final AwardPeriod period;
  final DateTime periodStart;
  final int place;
  final int points;

  /// Players ranked in the community that period.
  final int players;

  const CommunityAward({
    required this.id,
    required this.communityId,
    required this.communityName,
    required this.communityType,
    required this.period,
    required this.periodStart,
    required this.place,
    required this.points,
    required this.players,
  });

  factory CommunityAward.fromJson(Map<String, dynamic> json) => CommunityAward(
    id: (json['id'] as num).toInt(),
    communityId: json['community_id'] as String,
    communityName: json['community_name'] as String? ?? 'Community',
    communityType: CommunityType.fromName(json['community_type'] as String?),
    period: AwardPeriod.fromName(json['period'] as String?),
    periodStart: DateTime.parse(json['period_start'] as String),
    place: (json['place'] as num).toInt(),
    points: (json['points'] as num?)?.toInt() ?? 0,
    players: (json['players'] as num?)?.toInt() ?? 0,
  );

  bool get isTrophy => period == AwardPeriod.month;

  int get prestige => awardPrestige(period, communityType, place);

  String get asset => AwardIcons.forPlace(period, place);

  /// "1st in Global".
  String get title => '${awardPlaceLabel(place)} in $communityName';

  /// "October 2026" / "Week of 5 Oct".
  String get periodLabel => awardPeriodLabel(period, periodStart);

  @override
  List<Object?> get props => [
    id,
    communityId,
    communityName,
    communityType,
    period,
    periodStart,
    place,
    points,
    players,
  ];
}

/// Most important first, then newest.
List<CommunityAward> sortByPrestige(Iterable<CommunityAward> awards) =>
    [...awards]..sort((a, b) {
      final byPrestige = a.prestige.compareTo(b.prestige);
      return byPrestige != 0
          ? byPrestige
          : b.periodStart.compareTo(a.periodStart);
    });

/// Trophy and medal counts, for profile summaries.
class AwardTally extends Equatable {
  final int trophies;
  final int gold;
  final int silver;
  final int bronze;

  const AwardTally({
    this.trophies = 0,
    this.gold = 0,
    this.silver = 0,
    this.bronze = 0,
  });

  factory AwardTally.of(Iterable<CommunityAward> awards) {
    var trophies = 0, gold = 0, silver = 0, bronze = 0;
    for (final a in awards) {
      if (a.isTrophy) {
        trophies++;
      } else if (a.place == 1) {
        gold++;
      } else if (a.place == 2) {
        silver++;
      } else {
        bronze++;
      }
    }
    return AwardTally(
      trophies: trophies,
      gold: gold,
      silver: silver,
      bronze: bronze,
    );
  }

  int get medals => gold + silver + bronze;
  bool get isEmpty => trophies == 0 && medals == 0;

  @override
  List<Object?> get props => [trophies, gold, silver, bronze];
}

/// A winner of a community's latest finished week or month.
class AwardWinner extends Equatable {
  final int place;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int points;
  final int level;
  final int players;
  final DateTime periodStart;
  final bool isMe;

  const AwardWinner({
    required this.place,
    required this.userId,
    required this.username,
    required this.points,
    required this.level,
    required this.periodStart,
    this.displayName,
    this.avatarUrl,
    this.players = 0,
    this.isMe = false,
  });

  factory AwardWinner.fromJson(Map<String, dynamic> json) => AwardWinner(
    place: (json['place'] as num).toInt(),
    userId: json['user_id'] as String,
    username: json['username'] as String? ?? 'VitalUp user',
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    points: (json['points'] as num?)?.toInt() ?? 0,
    level: (json['level'] as num?)?.toInt() ?? 1,
    players: (json['players'] as num?)?.toInt() ?? 0,
    periodStart: DateTime.parse(json['period_start'] as String),
    isMe: json['is_me'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    place,
    userId,
    username,
    displayName,
    avatarUrl,
    points,
    level,
    players,
    periodStart,
    isMe,
  ];
}

/// One community's winners for its latest finished period.
class CommunityWinners extends Equatable {
  final Community community;
  final AwardPeriod period;
  final List<AwardWinner> winners;

  const CommunityWinners({
    required this.community,
    required this.period,
    required this.winners,
  });

  DateTime? get periodStart => winners.firstOrNull?.periodStart;

  @override
  List<Object?> get props => [community, period, winners];
}
