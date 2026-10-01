import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
            'text': m.bullets.isEmpty
                ? m.text
                : '${m.text}\n${m.bullets.map((b) => '- $b').join('\n')}',
          },
      ],
    });

    return VitaMessage(
      sender: VitaSender.vita,
      text: (data['text'] as String? ?? '').trim(),
      bullets: (data['bullets'] as List?)?.whereType<String>().toList() ?? const [],
      action: VitaAction.fromWire(data['action']),
      planInstructions: (data['planInstructions'] as String?)?.trim(),
      sentAt: DateTime.now(),
    );
  }

  /// headline / stressTip / dietNote for today.
  Future<Map<String, dynamic>> insights(Map<String, dynamic> snapshot) =>
      _invoke({'mode': 'insights', 'snapshot': snapshot});

  Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body, {
    bool retried = false,
  }) async {
    if (_client.auth.currentSession == null) {
      throw const VitaException('Please sign in to chat with Vita.');
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
        throw const VitaException("Vita couldn't respond right now. Please try again.");
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
          throw const VitaException('Your session expired. Please sign in again.');
        }
        return _invoke(body, retried: true);
      }
      throw switch (e.status) {
        401 => const VitaException('Your session expired. Please sign in again.'),
        429 => const VitaException(
            "You've reached today's Vita limit. Please try again tomorrow.",
            dailyLimit: true,
          ),
        _ => const VitaException("Vita couldn't respond right now. Please try again."),
      };
    } on TimeoutException {
      throw const VitaException('Vita is taking too long. Please try again.');
    } on SocketException {
      throw const VitaException(
        "You're offline. Vita will reply once you're back online.",
        offline: true,
      );
    } catch (e) {
      final offline = e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('ClientException');
      throw VitaException(
        offline
            ? "You're offline. Vita will reply once you're back online."
            : "Vita couldn't respond right now. Please try again.",
        offline: offline,
      );
    }
  }
}
