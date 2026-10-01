import 'package:equatable/equatable.dart';

/// An achievement from the `badges` catalog, earned or not.
class GameBadge extends Equatable {
  final String code;
  final String name;
  final String description;
  final String iconKey;
  final int bonusPoints;
  final DateTime? earnedAt;

  const GameBadge({
    required this.code,
    required this.name,
    required this.description,
    required this.iconKey,
    this.bonusPoints = 0,
    this.earnedAt,
  });

  bool get earned => earnedAt != null;

  factory GameBadge.fromJson(Map<String, dynamic> json, {DateTime? earnedAt}) =>
      GameBadge(
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        iconKey: json['icon_key'] as String? ?? json['code'] as String,
        bonusPoints: (json['bonus_points'] as num?)?.toInt() ?? 0,
        earnedAt: earnedAt,
      );

  @override
  List<Object?> get props => [
    code,
    name,
    description,
    iconKey,
    bonusPoints,
    earnedAt,
  ];
}
