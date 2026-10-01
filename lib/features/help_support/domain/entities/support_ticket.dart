enum SupportCategory {
  bug(
    label: 'Bug Report',
    icon: '🐛',
    description: 'Something is broken or not functioning properly.',
  ),
  feature(
    label: 'Feature Request',
    icon: '💡',
    description: 'Suggest a new capability or improvement.',
  ),
  healthSync(
    label: 'Health Connect & Sync',
    icon: '🔗',
    description: 'Issues syncing with Health Connect or Apple Health.',
  ),
  tracking(
    label: 'Tracking & Metrics',
    icon: '📊',
    description: 'Questions about Sleep, Water, Steps, or Screen Time.',
  ),
  account(
    label: 'Account & Data Privacy',
    icon: '🔒',
    description: 'Profile, login, data export, or account deletion.',
  ),
  general(
    label: 'General Inquiry',
    icon: '❓',
    description: 'General feedback, partnerships, or questions.',
  );

  final String label;
  final String icon;
  final String description;

  const SupportCategory({
    required this.label,
    required this.icon,
    required this.description,
  });
}

class SupportTicket {
  final SupportCategory category;
  final String subject;
  final String description;
  final String userEmail;
  final bool includeDiagnostics;
  final String? appVersion;
  final String? osPlatform;
  final String? deviceModel;
  final DateTime createdAt;

  SupportTicket({
    required this.category,
    required this.subject,
    required this.description,
    this.userEmail = '',
    this.includeDiagnostics = true,
    this.appVersion,
    this.osPlatform,
    this.deviceModel,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String toFormattedEmailBody() {
    final buffer = StringBuffer();
    buffer.writeln('Category: ${category.icon} ${category.label}');
    buffer.writeln('Subject: $subject');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Description:');
    buffer.writeln(description.trim());
    buffer.writeln('----------------------------------------');

    if (includeDiagnostics) {
      buffer.writeln();
      buffer.writeln('Diagnostics & Environment:');
      if (appVersion != null) buffer.writeln('• App Version: $appVersion');
      if (osPlatform != null) buffer.writeln('• Platform: $osPlatform');
      if (deviceModel != null) buffer.writeln('• Device Model: $deviceModel');
      buffer.writeln('• Timestamp: ${createdAt.toIso8601String()}');
      buffer.writeln('• Timezone: ${DateTime.now().timeZoneName} (Offset: ${DateTime.now().timeZoneOffset.inHours}h)');
    }

    return buffer.toString();
  }
}
