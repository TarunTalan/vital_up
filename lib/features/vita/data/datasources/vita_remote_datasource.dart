import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';

/// Calls the `vita-chat` Supabase edge function (Gemini with Groq fallback).
/// All failures surface as [VitaException] with a user-facing message.
class VitaRemoteDataSource {
  final SupabaseClient _client;

  static const _function = 'vita-chat';
  static const _timeout = Duration(seconds: 45);

  /// Last N turns sent as context (the server caps this too).
  static const maxContextMessages = 12;

  VitaRemoteDataSource(this._client);

  Future<VitaMessage> chat({
    required List<VitaMessage> history,
    required Map<String, dynamic> snapshot,
  }) async {
    // Earlier unanswered messages are noise for the model.
    final turns = history.where((m) => !m.failed).toList();
    final context = turns.length > maxContextMessages
        ? turns.sublist(turns.length - maxContextMessages)
        : turns;

    final data = await _invoke({
      'mode': 'chat',
      'snapshot': snapshot,
      'messages': [
        for (final m in context)
          {
            'role': m.isFromVita ? 'vita' : 'user',
            'text': _clip(
              m.bullets.isEmpty
                  ? m.text
                  : '${m.text}\n${m.bullets.map((b) => '- $b').join('\n')}',
            ),
          },
      ],
    });

    final text = data['text'];
    final plan = data['planInstructions'];
    return VitaMessage(
      sender: VitaSender.vita,
      text: text is String ? text.trim() : '',
      bullets: [
        for (final b in (data['bullets'] is List ? data['bullets'] as List : const []))
          if (b is String && b.trim().isNotEmpty) b.trim(),
      ],
      action: VitaAction.fromWire(data['action']),
      planInstructions: plan is String && plan.trim().isNotEmpty ? plan.trim() : null,
      sentAt: DateTime.now(),
    );
  }

  /// Longest single turn sent as context; older long replies are cut so the
  /// request stays small.
  static const maxTurnChars = 2000;

  static String _clip(String text) =>
      text.length <= maxTurnChars ? text : text.substring(0, maxTurnChars);

  /// headline / stressTip / dietNote for today.
  Future<Map<String, dynamic>> insights(Map<String, dynamic> snapshot) =>
      _invoke({'mode': 'insights', 'snapshot': snapshot});

  Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body, {
    bool retried = false,
  }) async {
    if (_client.auth.currentSession == null) {
      throw const VitaException(VitaException.signIn);
    }
    try {
      // An access token that expired while the app sat in the background is
      // rejected; refresh before calling rather than burning a 401 round trip.
      if (_client.auth.currentSession?.isExpired ?? false) {
        await _client.auth.refreshSession();
      }
      final response = await _client.functions
          .invoke(_function, body: body)
          .timeout(_timeout);
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data is! Map<String, dynamic>) {
        debugPrint('vita-chat returned unexpected data: ${data.runtimeType}');
        throw const VitaException(VitaException.couldNotReply);
      }
      return data;
    } on VitaException {
      rethrow;
    } on FunctionException catch (e) {
      debugPrint('vita-chat failed: status=${e.status} details=${e.details}');
      if (e.status == 401 && !retried) {
        // Token rejected server-side (revoked / stale): refresh once, retry.
        try {
          await _client.auth.refreshSession();
        } catch (refreshError) {
          debugPrint('vita-chat session refresh failed: $refreshError');
          throw const VitaException(VitaException.sessionExpired);
        }
        return _invoke(body, retried: true);
      }
      if (e.status == 0 || isOfflineError(e)) {
        throw const VitaException(VitaException.offlineMessage, offline: true);
      }
      throw switch (e.status) {
        401 => const VitaException(VitaException.sessionExpired),
        429 => const VitaException(
            VitaException.dailyLimitReached,
            dailyLimit: true,
          ),
        _ => const VitaException(VitaException.couldNotReply),
      };
    } on TimeoutException {
      throw const VitaException(VitaException.tooSlow);
    } on SocketException {
      throw const VitaException(VitaException.offlineMessage, offline: true);
    } catch (e) {
      debugPrint('vita-chat failed: $e');
      final offline = isOfflineError(e);
      throw VitaException(
        offline ? VitaException.offlineMessage : VitaException.couldNotReply,
        offline: offline,
      );
    }
  }
}
