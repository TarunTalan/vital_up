import 'package:equatable/equatable.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

/// One row of the points ledger: what a rule awarded on a day.
class PointEvent extends Equatable {
  final DateTime day;
  final String source;
  final ScoreCategory category;
  final int points;

  const PointEvent({
    required this.day,
    required this.source,
    required this.category,
    required this.points,
  });

  factory PointEvent.fromJson(Map<String, dynamic> json) => PointEvent(
    day: DateTime.parse(json['day'] as String),
    source: json['source'] as String,
    category:
        ScoreCategory.fromCode(json['category'] as String?) ??
        ScoreCategory.bonus,
    points: (json['points'] as num).toInt(),
  );

  @override
  List<Object?> get props => [day, source, category, points];
}

/// How a point source scores (`point_rules`), for the "How to earn" list.
class PointRule extends Equatable {
  final String source;
  final ScoreCategory category;
  final String name;
  final int points;
  final String unit;
  final int? dailyCap;

  const PointRule({
    required this.source,
    required this.category,
    required this.name,
    required this.points,
    required this.unit,
    this.dailyCap,
  });

  factory PointRule.fromJson(Map<String, dynamic> json) => PointRule(
    source: json['source'] as String,
    category:
        ScoreCategory.fromCode(json['category'] as String?) ??
        ScoreCategory.bonus,
    name: json['name'] as String,
    points: (json['points'] as num).toInt(),
    unit: json['unit'] as String? ?? 'each',
    dailyCap: (json['daily_cap'] as num?)?.toInt(),
  );

  @override
  List<Object?> get props => [source, category, name, points, unit, dailyCap];
}
