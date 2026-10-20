import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends support tickets through the `send-email` Edge Function (Resend).
///
/// The function only accepts tickets from a signed-in user and takes the
/// sender's email from the session, so it can't be used to mail anyone else.
class EmailService {
  final SupabaseClient _supabase;
  final Logger _logger = Logger();

  EmailService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

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
      final res = await _supabase.functions
          .invoke('send-email', body: body)
          .timeout(const Duration(seconds: 30));

      if (res.status == 200) {
        _logger.i('Support ticket sent.');
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
