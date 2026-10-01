import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What a challenge ranks on; scores come from synced workouts.
enum ChallengeMetric {
  activeMinutes('active_minutes', 'Active minutes', 'min'),
  distanceKm('distance_km', 'Distance', 'km'),
  workouts('workouts', 'Workouts', '');

  final String code;
  final String label;
  final String unit;
  const ChallengeMetric(this.code, this.label, this.unit);

  static ChallengeMetric fromCode(String? code) =>
      values.where((m) => m.code == code).firstOrNull ?? activeMinutes;

  /// "42 min", "12.5 km", "3 workouts".
  String format(num score) => switch (this) {
    ChallengeMetric.distanceKm => '${score.toStringAsFixed(1)} km',
    ChallengeMetric.workouts =>
      '${score.toInt()} ${score == 1 ? 'workout' : 'workouts'}',
    ChallengeMetric.activeMinutes => '${score.toInt()} min',
  };
}

enum ParticipantStatus {
  invited,
  joined,
  declined;

  static ParticipantStatus fromName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? invited;
}

class Challenge extends Equatable {
  final String id;
  final ChallengeMetric metric;
  final DateTime startsAt;
  final DateTime endsAt;
  final String creatorUsername;
  final ParticipantStatus myStatus;
  final int participants;
  final double? myScore;
  final int? myRank;

  const Challenge({
    required this.id,
    required this.metric,
    required this.startsAt,
    required this.endsAt,
    required this.creatorUsername,
    required this.myStatus,
    required this.participants,
    this.myScore,
    this.myRank,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'] as String,
    metric: ChallengeMetric.fromCode(json['metric'] as String?),
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
    creatorUsername: json['creator_username'] as String? ?? 'VitalUp user',
    myStatus: ParticipantStatus.fromName(json['my_status'] as String?),
    participants: (json['participants'] as num?)?.toInt() ?? 0,
    myScore: (json['my_score'] as num?)?.toDouble(),
    myRank: (json['my_rank'] as num?)?.toInt(),
  );

  bool isActiveAt(DateTime now) => now.isBefore(endsAt);

  @override
  List<Object?> get props => [
    id,
    metric,
    startsAt,
    endsAt,
    creatorUsername,
    myStatus,
    participants,
    myScore,
    myRank,
  ];
}

class ChallengeStanding extends Equatable {
  final String userId;
  final String username;
  final String? avatarUrl;
  final ParticipantStatus status;
  final double? score;
  final int? rank;
  final bool isMe;

  const ChallengeStanding({
    required this.userId,
    required this.username,
    required this.status,
    required this.isMe,
    this.avatarUrl,
    this.score,
    this.rank,
  });

  factory ChallengeStanding.fromJson(Map<String, dynamic> json) =>
      ChallengeStanding(
        userId: json['user_id'] as String,
        username: json['username'] as String? ?? 'VitalUp user',
        avatarUrl: json['avatar_url'] as String?,
        status: ParticipantStatus.fromName(json['status'] as String?),
        score: (json['score'] as num?)?.toDouble(),
        rank: (json['rank'] as num?)?.toInt(),
        isMe: json['is_me'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [userId, username, avatarUrl, status, score, rank];
}

/// A request the server refused, with a message for the user.
class ChallengeException implements Exception {
  final String message;
  const ChallengeException(this.message);

  static ChallengeException fromServer(String serverMessage) {
    const messages = {
      'no_friends_selected': 'Pick at least one friend.',
      'too_many_friends': 'You can challenge up to 9 friends at once.',
      'too_many_challenges':
          "You've started 5 challenges today. Try again tomorrow.",
      'invite_not_found': 'That challenge has ended or was already answered.',
      'challenge_not_found': "That challenge isn't available.",
    };
    for (final e in messages.entries) {
      if (serverMessage.contains(e.key)) return ChallengeException(e.value);
    }
    return const ChallengeException("Couldn't reach the server. Try again.");
  }

  @override
  String toString() => message;
}

class ChallengesRepository {
  final SupabaseClient _client;

  ChallengesRepository(this._client);

  Future<List<Challenge>> getChallenges() async {
    final rows = await _call(() => _client.rpc('get_challenges'));
    return [
      for (final r in rows as List)
        Challenge.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<List<ChallengeStanding>> getLeaderboard(String challengeId) async {
    final rows = await _call(
      () => _client.rpc(
        'get_challenge_leaderboard',
        params: {'p_challenge': challengeId},
      ),
    );
    return [
      for (final r in rows as List)
        ChallengeStanding.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> create({
    required ChallengeMetric metric,
    required int days,
    required List<String> friendIds,
  }) => _call(
    () => _client.rpc(
      'create_challenge',
      params: {
        'p_metric': metric.code,
        'p_days': days,
        'p_friend_ids': friendIds,
      },
    ),
  );

  Future<void> respond(Challenge challenge, {required bool accept}) => _call(
    () => _client.rpc(
      'respond_to_challenge',
      params: {'p_challenge': challenge.id, 'p_accept': accept},
    ),
  );

  Future<dynamic> _call(Future<dynamic> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw ChallengeException.fromServer(e.message);
    } catch (_) {
      throw const ChallengeException("Couldn't reach the server. Try again.");
    }
  }
}
