import 'package:equatable/equatable.dart';

/// An achievement from the `badges` catalog, earned or not.
class GameBadge extends Equatable {
  final String code;
  final String name;
  final String description;
  final String iconKey;
  final int bonusPoints;
  final DateTime? earnedAt;

  /// Where the user stands toward [threshold] ("7 of 10 workouts"); null
  /// when unknown (offline before the first load).
  final int? progress;
  final int? threshold;

  const GameBadge({
    required this.code,
    required this.name,
    required this.description,
    required this.iconKey,
    this.bonusPoints = 0,
    this.earnedAt,
    this.progress,
    this.threshold,
  });

  bool get earned => earnedAt != null;

  /// 0-1 toward unlocking, for locked badges with known progress.
  double? get progressFraction {
    final p = progress;
    final t = threshold;
    if (earned || p == null || t == null || t <= 0) return null;
    return (p / t).clamp(0.0, 1.0);
  }

  factory GameBadge.fromJson(
    Map<String, dynamic> json, {
    DateTime? earnedAt,
    Map<String, dynamic>? progress,
  }) => GameBadge(
    code: json['code'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    iconKey: json['icon_key'] as String? ?? json['code'] as String,
    bonusPoints: (json['bonus_points'] as num?)?.toInt() ?? 0,
    earnedAt: earnedAt,
    progress: (progress?['value'] as num?)?.toInt(),
    threshold:
        (progress?['threshold'] as num?)?.toInt() ??
        (json['threshold'] as num?)?.toInt(),
  );

  @override
  List<Object?> get props => [
    code,
    name,
    description,
    iconKey,
    bonusPoints,
    earnedAt,
    progress,
    threshold,
  ];
}
