import 'package:equatable/equatable.dart';

/// Area of the app a health signal is drawn from — picks the row icon.
enum HealthSignalKind { diet, metrics, sleep, stress, activity, medication }

class HealthSignal extends Equatable {
  final HealthSignalKind kind;
  final String title;
  final String summary;

  /// Individual data points behind this row (for the "N signals" count).
  final int dataPoints;

  const HealthSignal({
    required this.kind,
    required this.title,
    required this.summary,
    this.dataPoints = 1,
  });

  @override
  List<Object?> get props => [kind, title, summary, dataPoints];
}

class HealthAnalysis extends Equatable {
  final List<HealthSignal> signals;

  /// AI one-liner across all data; null offline / before first fetch.
  final String? headline;

  const HealthAnalysis({required this.signals, this.headline});

  int get signalCount => signals.fold(0, (sum, s) => sum + s.dataPoints);
  int get featureCount => signals.length;

  @override
  List<Object?> get props => [signals, headline];
}

enum TriggerSeverity {
  low('Low', 5),
  medium('Medium', 15),
  high('High', 25);

  final String label;

  /// Points this trigger adds to the estimated stress score.
  final int weight;
  const TriggerSeverity(this.label, this.weight);
}

class StressTrigger extends Equatable {
  final String name;
  final TriggerSeverity severity;

  const StressTrigger({required this.name, required this.severity});

  @override
  List<Object?> get props => [name, severity];
}

enum StressLevel {
  low('Low Stress'),
  moderate('Moderate Stress'),
  high('High Stress');

  final String label;
  const StressLevel(this.label);

  static StressLevel fromScore(int score) => score < 35
      ? StressLevel.low
      : score < 65
          ? StressLevel.moderate
          : StressLevel.high;
}

/// What today's stress score is based on, most to least reliable.
enum StressSource {
  checkInAndWearable('From your check-in and watch data'),
  checkIn("From today's check-in"),
  wearable('From your watch heart data'),
  estimated('Estimated from your sleep, activity, meals and screen time');

  final String description;
  const StressSource(this.description);
}

/// What's behind a stress check-in (optional chips on the dashboard).
enum StressTag {
  work('Work', '💼'),
  sleep('Sleep', '😴'),
  family('Family', '🏠'),
  health('Health', '🩺'),
  money('Money', '💸'),
  social('Social', '🫂'),
  other('Other', '✨');

  final String label;
  final String emoji;
  const StressTag(this.label, this.emoji);

  static StressTag? fromName(String name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// Self-reported stress, 1 (very calm) – 5 (very stressed).
class StressCheckIn extends Equatable {
  static const labels = [
    'Very calm',
    'Calm',
    'Okay',
    'Stressed',
    'Very stressed',
  ];

  /// Mood faces for levels 1–5.
  static const emojis = ['😌', '🙂', '😐', '😣', '😫'];

  final DateTime date;
  final int level;
  final List<StressTag> tags;

  const StressCheckIn({
    required this.date,
    required this.level,
    this.tags = const [],
  });

  String get label => labels[(level - 1).clamp(0, 4)];
  String get emoji => emojis[(level - 1).clamp(0, 4)];

  Map<String, dynamic> toJson() => {
        'd': date.toIso8601String(),
        'l': level,
        if (tags.isNotEmpty) 't': [for (final t in tags) t.name],
      };

  /// Older check-ins have no `t` (tags) key.
  factory StressCheckIn.fromJson(Map<String, dynamic> json) => StressCheckIn(
        date: DateTime.parse(json['d'] as String),
        level: json['l'] as int,
        tags: [
          for (final name in (json['t'] as List? ?? const []).whereType<String>())
            ?StressTag.fromName(name),
        ],
      );

  @override
  List<Object?> get props => [date, level, tags];
}

/// Consecutive days with a check-in, ending today — or yesterday when today
/// isn't logged yet, so the streak doesn't look broken in the morning.
int stressStreak(Iterable<StressCheckIn> checkIns, {DateTime? now}) {
  final days = {
    for (final c in checkIns)
      DateTime(c.date.year, c.date.month, c.date.day),
  };
  final today = now ?? DateTime.now();
  var day = DateTime(today.year, today.month, today.day);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

class StressReport extends Equatable {
  /// 0 (calm) – 100 (very stressed).
  final int score;
  final StressLevel level;
  final StressSource source;
  final String trend;
  final List<StressTrigger> triggers;
  final StressCheckIn? todayCheckIn;

  /// AI technique tip; null offline / before first fetch.
  final String? tip;

  /// Whether wearable heart data could be connected for better accuracy.
  final bool canConnectWearable;

  const StressReport({
    required this.score,
    required this.level,
    required this.source,
    required this.trend,
    required this.triggers,
    this.todayCheckIn,
    this.tip,
    this.canConnectWearable = false,
  });

  StressReport copyWith({String? tip, bool? canConnectWearable}) =>
      StressReport(
        score: score,
        level: level,
        source: source,
        trend: trend,
        triggers: triggers,
        todayCheckIn: todayCheckIn,
        tip: tip ?? this.tip,
        canConnectWearable: canConnectWearable ?? this.canConnectWearable,
      );

  @override
  List<Object?> get props =>
      [score, level, source, trend, triggers, todayCheckIn, tip, canConnectWearable];
}

/// AI text refreshed once a day across Vita screens.
class VitaDailyInsights extends Equatable {
  final DateTime date;
  final String? headline;
  final String? stressTip;
  final String? dietNote;

  const VitaDailyInsights({
    required this.date,
    this.headline,
    this.stressTip,
    this.dietNote,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'headline': headline,
        'stressTip': stressTip,
        'dietNote': dietNote,
      };

  factory VitaDailyInsights.fromJson(Map<String, dynamic> json) =>
      VitaDailyInsights(
        date: DateTime.parse(json['date'] as String),
        headline: _nonEmpty(json['headline']),
        stressTip: _nonEmpty(json['stressTip']),
        dietNote: _nonEmpty(json['dietNote']),
      );

  @override
  List<Object?> get props => [date, headline, stressTip, dietNote];
}

String? _nonEmpty(Object? value) {
  final s = value?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
