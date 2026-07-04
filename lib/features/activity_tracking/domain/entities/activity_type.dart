enum ActivityType {
  walk,
  run,
  cycle,
}

extension ActivityTypeLabel on ActivityType {
  String get label {
    return switch (this) {
      ActivityType.walk => 'Walking',
      ActivityType.run => 'Running',
      ActivityType.cycle => 'Cycling',
    };
  }

  double get maxReasonableSpeedMetersPerSecond {
    return switch (this) {
      ActivityType.walk => 3.2,
      ActivityType.run => 8.0,
      ActivityType.cycle => 18.0,
    };
  }

  double get met {
    return switch (this) {
      ActivityType.walk => 3.8,
      ActivityType.run => 9.8,
      ActivityType.cycle => 7.5,
    };
  }
}
