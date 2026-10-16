import 'package:equatable/equatable.dart';

/// The caller's place in one community board, for the Arena tiles.
class CommunityStanding extends Equatable {
  final String communityId;

  /// Null without points this period.
  final int? rank;
  final int points;

  /// Players with points on the board.
  final int rankedCount;

  /// Accepted friends ranked on the board.
  final int friendCount;

  const CommunityStanding({
    required this.communityId,
    this.rank,
    this.points = 0,
    this.rankedCount = 0,
    this.friendCount = 0,
  });

  factory CommunityStanding.fromJson(Map<String, dynamic> json) =>
      CommunityStanding(
        communityId: json['community_id'] as String,
        rank: (json['rank'] as num?)?.toInt(),
        points: (json['points'] as num?)?.toInt() ?? 0,
        rankedCount: (json['ranked_count'] as num?)?.toInt() ?? 0,
        friendCount: (json['friend_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
    communityId,
    rank,
    points,
    rankedCount,
    friendCount,
  ];
}
