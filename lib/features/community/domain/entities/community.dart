import 'package:equatable/equatable.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

enum CommunityType {
  global,
  local,
  interest,

  /// The caller and their accepted friends; built on the device, not a
  /// `communities` row.
  friends;

  static CommunityType fromName(String? name) =>
      values.where((t) => t.name == name).firstOrNull ?? interest;
}

class Community extends Equatable {
  final String id;
  final String slug;
  final String name;
  final CommunityType type;
  final String? city;
  final String? description;
  final String iconKey;

  /// Categories this community ranks on; empty means the total score.
  final List<ScoreCategory> scoreCategories;
  final int memberCount;
  final bool isMember;

  const Community({
    required this.id,
    required this.slug,
    required this.name,
    required this.type,
    required this.iconKey,
    this.city,
    this.description,
    this.scoreCategories = const [],
    this.memberCount = 0,
    this.isMember = false,
  });

  /// The caller's friends, ranked on the total score.
  static Community friendsOf(int friendCount) => Community(
    id: 'friends',
    slug: 'friends',
    name: 'Friends',
    type: CommunityType.friends,
    iconKey: 'friends',
    description: 'You and your friends',
    memberCount: friendCount + 1,
    isMember: true,
  );

  /// Only interest communities are joined and left by hand.
  bool get canJoin => type == CommunityType.interest;

  /// What the leaderboard ranks on, for the subtitle.
  String get rankedOn => scoreCategories.isEmpty
      ? 'Total score'
      : scoreCategories.map((c) => c.label).join(' + ');

  factory Community.fromJson(Map<String, dynamic> json) => Community(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
    type: CommunityType.fromName(json['type'] as String?),
    city: json['city'] as String?,
    description: json['description'] as String?,
    iconKey: json['icon_key'] as String? ?? json['slug'] as String,
    scoreCategories: [
      for (final c in (json['score_categories'] as List? ?? const []))
        ?ScoreCategory.fromCode(c as String?),
    ],
    memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    isMember: json['is_member'] as bool? ?? false,
  );

  Community copyWith({bool? isMember, int? memberCount}) => Community(
    id: id,
    slug: slug,
    name: name,
    type: type,
    iconKey: iconKey,
    city: city,
    description: description,
    scoreCategories: scoreCategories,
    memberCount: memberCount ?? this.memberCount,
    isMember: isMember ?? this.isMember,
  );

  @override
  List<Object?> get props => [
    id,
    slug,
    name,
    type,
    city,
    description,
    iconKey,
    scoreCategories,
    memberCount,
    isMember,
  ];
}
