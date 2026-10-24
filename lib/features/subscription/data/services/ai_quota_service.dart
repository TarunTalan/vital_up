import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/utils/quota_reset.dart';
import 'package:vital_up/features/subscription/domain/pro_limits.dart';

/// A daily AI allowance the app shows a count for.
enum AiQuota {
  vitaChat('vita_chat', ProLimits.vitaChats, ProReason.vitaChats),
  dietPlan('diet_plan', ProLimits.dietPlans, ProReason.dietPlans);

  /// `ai_usage_daily.feature` on the server.
  final String feature;
  final ProLimit limit;

  /// What the Pro sheet says when this one runs out.
  final ProReason reason;

  const AiQuota(this.feature, this.limit, this.reason);
}

/// Free uses left today for [AiQuota]s, for the "12 of 15 messages left
/// today" lines.
///
/// The first read counts the user's own `ai_usage_daily` row (readable by
/// its owner) against the free limit; after that, every AI answer reports
/// the server's own count ([report]), so the line follows each use
/// without another request. Counts are kept per server day (India time),
/// so one saved yesterday reads as a fresh allowance. Display only: the
/// server enforces the real limits.
class AiQuotaService {
  final CacheStore _cache;

  /// Uses of [feature] counted on [day]; replaced in tests.
  final Future<int> Function(String userId, String feature, String day) _usedOn;

  /// The signed-in user's id; replaced in tests.
  final String? Function() _currentUserId;

  /// Reads through [client] (the signed-in user's own usage row) unless
  /// tests pass [usedOn] and [userId].
  AiQuotaService(
    this._cache, {
    SupabaseClient? client,
    Future<int> Function(String userId, String feature, String day)? usedOn,
    String? Function()? userId,
  }) : assert(client != null || (usedOn != null && userId != null)),
       _usedOn = usedOn ?? _readUsage(client!),
       _currentUserId = userId ?? (() => client!.auth.currentUser?.id);

  static const Duration _maxAge = Duration(minutes: 2);

  String? get _userId => _currentUserId();

  static String cacheKey(AiQuota quota, String userId) =>
      'ai_left_${quota.feature}_$userId';

  static Future<int> Function(String, String, String) _readUsage(
    SupabaseClient client,
  ) => (userId, feature, day) async {
    final rows = await client
        .from('ai_usage_daily')
        .select('use_count')
        .eq('user_id', userId)
        .eq('feature', feature)
        .eq('day', day)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['use_count'] as num?)?.toInt() ?? 0;
  };

  /// Fires when [quota]'s known count changes (a use, a refresh).
  Stream<void> changes(AiQuota quota) => _cache.changes
      .where((key) {
        final userId = _userId;
        return userId != null && key == cacheKey(quota, userId);
      })
      .map((_) {});

  /// Free uses of [quota] left today, or null when unknown (signed out,
  /// offline with no saved count).
  Future<int?> freeLeft(AiQuota quota, {bool forceRefresh = false}) async {
    final userId = _userId;
    if (userId == null) return null;
    final today = serverQuotaDay();
    try {
      final saved = await _cache.fetch<Map<String, dynamic>>(
        cacheKey(quota, userId),
        maxAge: _maxAge,
        forceRefresh: forceRefresh,
        decode: (json) => Map<String, dynamic>.from(json as Map),
        remote: () async {
          final used = await _usedOn(userId, quota.feature, today);
          return {'day': today, 'left': _clamp(quota, quota.limit.free - used)};
        },
      );
      // A count from an earlier server day: the allowance has reset.
      if (saved['day'] != today) return quota.limit.free;
      return _clamp(quota, (saved['left'] as num?)?.toInt() ?? 0);
    } catch (e) {
      debugPrint('AI quota ${quota.feature} unavailable: ${e.runtimeType}');
      return null;
    }
  }

  /// The server's count after a use ([left] uses left today). Saved so
  /// every line showing [quota] updates at once.
  Future<void> report(AiQuota quota, int left) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _cache.write(cacheKey(quota, userId), {
        'day': serverQuotaDay(),
        'left': _clamp(quota, left),
      });
    } catch (e) {
      debugPrint('AI quota ${quota.feature} not saved: ${e.runtimeType}');
    }
  }

  /// Counts are shown against the free allowance. Pro users don't see the
  /// line; their server counts run against the Pro cap, so they're capped
  /// here.
  static int _clamp(AiQuota quota, int left) => left.clamp(0, quota.limit.free);
}
