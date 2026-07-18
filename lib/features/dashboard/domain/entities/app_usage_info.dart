class AppUsageInfo {
  final String appName;
  final String packageName;
  final Duration usageDuration;

  const AppUsageInfo({
    required this.appName,
    required this.packageName,
    required this.usageDuration,
  });
}
