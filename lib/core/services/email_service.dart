import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for dispatching autonomous emails (notifications, announcements,
/// and custom transactional OTPs) powered by Resend via Supabase Edge Function.
///
/// Sender: noreply@vitalup.live
/// Reply-To: support@vitalup.live
class EmailService {
  final SupabaseClient _supabase;
  final Logger _logger = Logger();

  EmailService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Sends a transactional notification email.
  Future<bool> sendNotification({
    required String to,
    required String title,
    required String message,
    String? subject,
  }) async {
    final payload = <String, dynamic>{
      'to': to,
      'type': 'notification',
      'title': title,
      'message': message,
    };
    if (subject != null) payload['subject'] = subject;
    return _dispatch(payload);
  }

  /// Sends an announcement email to one or multiple recipients.
  Future<bool> sendAnnouncement({
    required List<String> to,
    required String title,
    required String message,
    String? subject,
  }) async {
    final payload = <String, dynamic>{
      'to': to,
      'type': 'announcement',
      'title': title,
      'message': message,
    };
    if (subject != null) payload['subject'] = subject;
    return _dispatch(payload);
  }

  /// Dispatches a custom OTP code.
  Future<bool> sendCustomOtp({
    required String to,
    required String otp,
    String? title,
    String? message,
  }) async {
    final payload = <String, dynamic>{
      'to': to,
      'type': 'otp',
      'otp': otp,
    };
    if (title != null) payload['title'] = title;
    if (message != null) payload['message'] = message;
    return _dispatch(payload);
  }

  /// Submits a contact support ticket:
  /// 1. Sends full user details and ticket inputs formatted into the brand template to support@vitalup.live
  /// 2. Sends an automated, branded ticket receipt confirmation to the user
  Future<bool> submitSupportTicket({
    required String userEmail,
    String? userName,
    String? userId,
    required String category,
    required String subject,
    required String description,
    bool includeDiagnostics = true,
    String? appVersion,
    String? osPlatform,
    String? deviceModel,
  }) async {
    final payload = <String, dynamic>{
      'type': 'support_ticket',
      'user_email': userEmail.trim(),
      if (userName != null && userName.trim().isNotEmpty)
        'user_name': userName.trim(),
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'category': category,
      'subject': subject.trim(),
      'description': description.trim(),
      'include_diagnostics': includeDiagnostics,
      'app_version': ?appVersion,
      'os_platform': ?osPlatform,
      'device_model': ?deviceModel,
      'created_at': DateTime.now().toIso8601String(),
    };
    return _dispatch(payload);
  }

  Future<bool> _dispatch(Map<String, dynamic> body) async {
    try {
      final res = await _supabase.functions.invoke(
        'send-email',
        body: body,
      );

      if (res.status == 200) {
        _logger.i('Email dispatched successfully to ${body['to']} via Resend.');
        return true;
      } else {
        _logger.e('Failed to send email: ${res.data}');
        return false;
      }
    } catch (e, st) {
      _logger.e('EmailService exception: $e', error: e, stackTrace: st);
      return false;
    }
  }
}
