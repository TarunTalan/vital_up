import 'package:flutter/material.dart';
import 'package:vital_up/core/utils/input_rules.dart';

enum SupportCategory {
  bug(
    label: 'Bug Report',
    icon: Icons.bug_report_rounded,
    description: 'Something is broken or not functioning properly.',
  ),
  feature(
    label: 'Feature Request',
    icon: Icons.lightbulb_rounded,
    description: 'Suggest a new capability or improvement.',
  ),
  healthSync(
    label: 'Health Connect & Sync',
    icon: Icons.sync_rounded,
    description: 'Issues syncing with Health Connect or Apple Health.',
  ),
  tracking(
    label: 'Tracking & Metrics',
    icon: Icons.insights_rounded,
    description: 'Questions about Sleep, Water, Steps, or Screen Time.',
  ),
  account(
    label: 'Account & Data Privacy',
    icon: Icons.lock_rounded,
    description: 'Profile, login, data export, or account deletion.',
  ),
  general(
    label: 'General Inquiry',
    icon: Icons.help_rounded,
    description: 'General feedback, partnerships, or questions.',
  );

  final String label;
  final IconData icon;
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
    buffer.writeln('Category: ${category.label}');
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
      buffer.writeln(
        '• Timezone: ${DateTime.now().timeZoneName} (Offset: ${DateTime.now().timeZoneOffset.inHours}h)',
      );
    }

    return buffer.toString();
  }
}

const kSupportEmail = 'support@vitalup.app';

/// `mailto:` link to support. Built by hand so spaces encode as `%20`:
/// `Uri(queryParameters:)` uses `+`, which many mail apps show literally.
Uri supportMailUri({String? subject, String? body}) {
  final query = [
    if (subject != null && subject.isNotEmpty)
      'subject=${Uri.encodeComponent(subject)}',
    if (body != null && body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
  ].join('&');
  return Uri.parse('mailto:$kSupportEmail${query.isEmpty ? '' : '?$query'}');
}

/// Limits and checks for the support ticket form.
abstract final class SupportTicketRules {
  static const subjectMax = InputLimits.shortText;
  static const descriptionMax = InputLimits.chatMessage;
  static const descriptionMin = 10;

  static String cleanSubject(String raw) =>
      sanitizeText(raw, maxLength: subjectMax);

  static String cleanDescription(String raw) =>
      sanitizeText(raw, maxLength: descriptionMax, multiline: true);

  /// Inline error for the description, or null when it's fine.
  static String? validateDescription(String raw) {
    final text = cleanDescription(raw);
    if (text.isEmpty) return 'Describe your issue or question.';
    if (text.characters.length < descriptionMin) {
      return 'Add a few more words so we can help.';
    }
    return null;
  }
}
