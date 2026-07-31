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
  };
}