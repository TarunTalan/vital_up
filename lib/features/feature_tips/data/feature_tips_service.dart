import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/feature_tips/domain/feature_tip.dart';

/// Puts a tip in the system notification schedule (local notifications).
abstract class TipScheduler {
  /// Whether notifications are allowed; null when it can't be told.
  Future<bool?> permitted();
  Future<void> schedule(FeatureTip tip, DateTime at);
  Future<void> cancel();
}

/// Tells users about features they haven't found, two ways:
///
/// - Notifications ("feature tips"): at most one a week, each tip once
///   ever, never in the first [FeatureTipRules.daysAfterInstall] days, at
///   a random afternoon time, only for features the user hasn't opened
///   (tracked by route name, [attach]). Off with the Settings switch
///   ([setEnabled]) or the system's notification permission. Local, so no
///   server and no account needed; scheduled ahead, so it arrives with the
///   app closed.
/// - In-app tips (`FeatureTipCard`) shown once where a feature helps,
///   remembered here ([isDismissed] / [dismiss]).
class FeatureTipsService {
  static const enabledKey = 'feature_tips_enabled_v1';
  static const installedKey = 'feature_tips_installed_at';
  static const shownKey = 'feature_tips_shown';
  static const lastKey = 'feature_tips_last_at';
  static const scheduledKey = 'feature_tips_scheduled';
  static const usedKey = 'feature_tips_used_routes';
  static const _dismissedPrefix = 'feature_tip_dismissed_';

  final SharedPreferences prefs;
  final TipScheduler scheduler;
  final DateTime Function() _now;
  final Random? _random;

  late final ValueNotifier<bool> enabled = ValueNotifier(
    prefs.getBool(enabledKey) ?? true,
  );

  FeatureTipsService(
    this.prefs,
    this.scheduler, {
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random;

  /// Route names that mark a tip's feature as used.
  static final Set<String> _trackedRoutes = {
    for (final tip in featureTips) ...tip.usedRoutes,
  };

  GoRouter? _router;
  Future<void>? _rescheduling;

  /// Follows navigation: opening a feature's page means its tip is moot.
  void attach(GoRouter router) {
    if (_router != null) return;
    _router = router;
    router.routerDelegate.addListener(() {
      try {
        final name = router.state.name;
        if (name != null) markUsed(name);
      } catch (_) {
        // No route yet (startup).
      }
    });
  }

  Set<String> get usedRoutes => (prefs.getStringList(usedKey) ?? []).toSet();

  /// Records a visit to [routeName] (only routes a tip is about).
  void markUsed(String routeName) {
    if (!_trackedRoutes.contains(routeName)) return;
    final used = usedRoutes;
    if (!used.add(routeName)) return;
    prefs.setStringList(usedKey, used.toList());
  }

  Future<void> setEnabled(bool on) async {
    enabled.value = on;
    await prefs.setBool(enabledKey, on);
    await reschedule();
  }

  /// At app start (and after changes): records a tip that has gone out,
  /// drops a planned one that no longer fits, plans the next.
  Future<void> reschedule() =>
      _rescheduling ??= _reschedule().whenComplete(() => _rescheduling = null);

  Future<void> _reschedule() async {
    try {
      final now = _now();
      final installedMs = prefs.getInt(installedKey);
      if (installedMs == null) {
        await prefs.setInt(installedKey, now.millisecondsSinceEpoch);
      }
      final installedAt = DateTime.fromMillisecondsSinceEpoch(
        installedMs ?? now.millisecondsSinceEpoch,
      );

      final planned = _planned();
      if (planned != null) {
        if (!planned.at.isAfter(now)) {
          // Sent while the app was closed.
          final shown = (prefs.getStringList(shownKey) ?? []).toSet()
            ..add(planned.id);
          await prefs.setStringList(shownKey, shown.toList());
          await prefs.setInt(lastKey, planned.at.millisecondsSinceEpoch);
          await prefs.remove(scheduledKey);
        } else {
          final tip = featureTips.where((t) => t.id == planned.id).firstOrNull;
          final stillFits =
              tip != null &&
              enabled.value &&
              !tip.usedRoutes.any(usedRoutes.contains) &&
              await scheduler.permitted() != false;
          if (stillFits) return;
          await scheduler.cancel();
          await prefs.remove(scheduledKey);
        }
      }

      if (!enabled.value) return;
      if (await scheduler.permitted() == false) return;
      final lastMs = prefs.getInt(lastKey);
      final next = FeatureTipRules.next(
        now: now,
        installedAt: installedAt,
        lastTipAt: lastMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastMs),
        shown: (prefs.getStringList(shownKey) ?? []).toSet(),
        usedRoutes: usedRoutes,
        random: _random,
      );
      if (next == null) return;
      await scheduler.schedule(next.tip, next.at);
      await prefs.setString(
        scheduledKey,
        jsonEncode({'id': next.tip.id, 'at': next.at.millisecondsSinceEpoch}),
      );
    } catch (e) {
      debugPrint('Feature tips: scheduling failed: $e');
    }
  }

  ({String id, DateTime at})? _planned() {
    final raw = prefs.getString(scheduledKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        id: json['id'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  /// The tip planned next and when (Settings, tests).
  ({String id, DateTime at})? get planned => _planned();

  /// An in-app tip the user has answered (either button).
  bool isDismissed(String key) =>
      prefs.getBool('$_dismissedPrefix$key') ?? false;

  Future<void> dismiss(String key) =>
      prefs.setBool('$_dismissedPrefix$key', true);
}
