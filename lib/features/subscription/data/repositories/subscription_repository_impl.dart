import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/features/food_scanner/data/utils/food_cache_keys.dart';
import 'package:vital_up/features/subscription/data/services/store_billing.dart';
import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';

/// The server's answer is cached per user so it is known offline (a stale
/// answer beats none). Remaining scans change with every photo scan, so
/// that copy is short-lived; a successful scan also decrements it in place
/// (see `FoodRecognitionRepositoryImpl`).
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SupabaseClient _client;
  final CacheStore _cache;
  final StoreBilling billing;

  SubscriptionRepositoryImpl({
    required SupabaseClient supabaseClient,
    required CacheStore cacheStore,
    required this.billing,
  }) : _client = supabaseClient,
       _cache = cacheStore;

  static const Duration _premiumMaxAge = Duration(hours: 1);
  static const Duration _remainingScansMaxAge = Duration(minutes: 2);
  static const Duration _syncTimeout = Duration(seconds: 10);

  String? get _userId => _client.auth.currentUser?.id;

  @override
  bool get canPurchase => billing.available;

  @override
  Future<void> identify(String? userId) => billing.identify(userId);

  @override
  Stream<ProStatus> get changes => billing.changes;

  Future<bool> _serverPro(String userId, {bool forceRefresh = false}) =>
      _cache.fetch<bool>(
        FoodCacheKeys.premium(userId),
        maxAge: _premiumMaxAge,
        forceRefresh: forceRefresh,
        decode: (json) => json as bool,
        remote: () async {
          final response = await _client.rpc(
            'is_premium_user',
            params: {'p_user_id': userId},
          );
          return response as bool? ?? false;
        },
      );

  @override
  Future<ProStatus> status({bool forceRefresh = false}) async {
    final userId = _userId;
    if (userId == null) return ProStatus.free;
    final results = await Future.wait([
      billing.status().then<ProStatus?>((s) => s).catchError((Object e) {
        debugPrint('Store status unavailable: ${e.runtimeType}');
        return null;
      }),
      _serverPro(
        userId,
        forceRefresh: forceRefresh,
      ).then<bool?>((pro) => pro).catchError((Object e) {
        debugPrint('Server plan unavailable: ${e.runtimeType}');
        return null;
      }),
    ]);
    final store = results[0] as ProStatus?;
    final server = results[1] as bool?;
    if (store == null && server == null) {
      throw StateError("Couldn't read the plan");
    }
    if (store?.isPro ?? false) return store!;
    // Granted on the server (support, a purchase the store hasn't shown on
    // this device yet): Pro without the store's details.
    if (server ?? false) {
      return ProStatus(isPro: true, managementUrl: store?.managementUrl);
    }
    return store ?? ProStatus.free;
  }

  @override
  Future<List<ProPlan>> plans() => billing.plans();

  @override
  Future<PurchaseOutcome> purchase(String planId) async {
    final outcome = await billing.purchase(planId);
    if (outcome is PurchaseCompleted) await syncServer();
    return outcome;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    final outcome = await billing.restore();
    if (outcome is PurchaseCompleted) await syncServer();
    return outcome;
  }

  @override
  Future<void> syncServer() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _client.functions
          .invoke('sync-subscription', method: HttpMethod.post)
          .timeout(_syncTimeout);
    } catch (e) {
      // The webhook catches up within seconds; nothing to show.
      debugPrint('Subscription sync failed: ${e.runtimeType}');
    }
    try {
      await _cache.remove(FoodCacheKeys.remainingScans(userId));
      await _serverPro(userId, forceRefresh: true);
    } catch (e) {
      debugPrint('Plan refresh failed: ${e.runtimeType}');
    }
  }

  @override
  Stream<void> get remainingScansChanges => _cache.changes
      .where((key) {
        final userId = _userId;
        return userId != null && key == FoodCacheKeys.remainingScans(userId);
      })
      .map((_) {});

  @override
  Future<int> remainingFreeScans() async {
    final userId = _userId;
    if (userId == null) return 0;
    return _cache.fetch<int>(
      FoodCacheKeys.remainingScans(userId),
      maxAge: _remainingScansMaxAge,
      decode: (json) => (json as num).toInt(),
      remote: () async {
        final response = await _client.rpc(
          'get_remaining_scans',
          params: {'p_user_id': userId},
        );
        return (response as num?)?.toInt() ?? 0;
      },
    );
  }
}
