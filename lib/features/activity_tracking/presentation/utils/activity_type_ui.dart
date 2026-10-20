import 'package:flutter/material.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

/// Icon representing each activity type, for use in history rows, filter
/// chips, etc.
IconData activityTypeIcon(ActivityType type) {
  return switch (type) {
    ActivityType.walk => Icons.directions_walk_rounded,
    ActivityType.run => Icons.directions_run_rounded,
    ActivityType.cycle => Icons.directions_bike_rounded,
    ActivityType.trekking => Icons.hiking_rounded,
    ActivityType.climbing => Icons.terrain_rounded,
    ActivityType.strength => Icons.fitness_center_rounded,
    ActivityType.yoga => Icons.self_improvement_rounded,
    ActivityType.hiit => Icons.bolt_rounded,
    ActivityType.swimming => Icons.pool_rounded,
    ActivityType.dance => Icons.music_note_rounded,
    ActivityType.sports => Icons.sports_tennis_rounded,
    ActivityType.other => Icons.sports_gymnastics_rounded,
  };
}
