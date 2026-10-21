import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';

/// A system permission VitalUp asks for, with the words its card uses.
/// The system dialog itself can't be restyled: the card explains first,
/// and the system dialog only follows a tap on Allow.
enum AppPermission {
  notifications(
    name: 'Notifications',
    why: 'Reminders, workout controls and updates from friends',
    privacy: 'You choose which reminders you get in Settings.',
    icon: Icons.notifications_active_rounded,
  ),
  location(
    name: 'Location',
    why: 'Your route, distance and pace while you track',
    privacy: 'Only used while the workout map is open or you track.',
    icon: Icons.location_on_rounded,
  ),
  activity(
    name: 'Physical activity',
    why: 'Counts your steps during a workout',
    privacy: 'Step counts stay with your workouts.',
    icon: Icons.directions_walk_rounded,
  ),
  camera(
    name: 'Camera',
    why: 'Scan meals, barcodes and nutrition labels',
    privacy: 'Only used while the scanner is open.',
    icon: Icons.photo_camera_rounded,
  );

  final String name;
  final String why;
  final String privacy;
  final IconData icon;

  const AppPermission({
    required this.name,
    required this.why,
    required this.privacy,
    required this.icon,
  });

  /// Null where the platform doesn't ask (activity on iOS: the system
  /// asks for Motion & Fitness itself when steps are read).
  Permission? get _system => switch (this) {
    AppPermission.notifications => Permission.notification,
    AppPermission.location => Permission.locationWhenInUse,
    AppPermission.activity =>
      Platform.isAndroid ? Permission.activityRecognition : null,
    AppPermission.camera => Permission.camera,
  };

  /// Whether it's allowed, without asking.
  Future<bool> isGranted() async {
    final system = _system;
    if (system == null) return true;
    try {
      final status = await system.status;
      return status.isGranted || status.isLimited;
    } catch (e) {
      debugPrint('Permission check failed for $name: $e');
      return false;
    }
  }

  /// The system won't show its dialog again: only Settings can allow it.
  Future<bool> isBlocked() async {
    try {
      final status = await _system?.status;
      return status != null &&
          (status.isPermanentlyDenied || status.isRestricted);
    } catch (_) {
      return false;
    }
  }

  /// Shows the system dialog. Call only after the user tapped Allow.
  Future<bool> request() async {
    final system = _system;
    if (system == null) return true;
    try {
      final status = await system.request();
      return status.isGranted || status.isLimited;
    } catch (e) {
      debugPrint('Permission request failed for $name: $e');
      return false;
    }
  }
}

/// What a card asks for, in the words of the moment: "Map your run"
/// rather than a bare "Location".
class PermissionAsk {
  final AppPermission main;

  /// Asked for together with [main] when missing; not required to go on.
  final List<AppPermission> also;
  final String title;
  final String message;

  /// Asked once: once this card has been answered (either way) it doesn't
  /// come back from here; the user can still turn it on in Settings. For
  /// permissions the feature works without.
  final String? onceKey;

  /// With [main] already allowed, [also] alone gets the card once, under
  /// this key (e.g. steps for someone who allowed location long ago).
  final String? alsoOnceKey;

  const PermissionAsk({
    required this.main,
    required this.title,
    required this.message,
    this.also = const [],
    this.onceKey,
    this.alsoOnceKey,
  });
}

const _askedPrefix = 'permission_card_asked_';

/// Makes sure [ask.main] is allowed, asking the VitalUp way: nothing when
/// it already is; otherwise a card that says why (and lists [ask.also]
/// when missing), then the system dialog only after Allow; when the
/// system won't ask again, the card offers Settings instead. Returns
/// whether [ask.main] is allowed now.
Future<bool> ensurePermission(BuildContext context, PermissionAsk ask) async {
  final missing = <AppPermission>[];
  for (final p in [ask.main, ...ask.also]) {
    if (!await p.isGranted()) missing.add(p);
  }
  final prefs = sl.isRegistered<SharedPreferences>()
      ? sl<SharedPreferences>()
      : null;
  if (!missing.contains(ask.main)) {
    // The extras alone never hold anything up, and get the card once.
    final alsoKey = ask.alsoOnceKey;
    if (missing.isEmpty ||
        alsoKey == null ||
        prefs?.getBool('$_askedPrefix$alsoKey') == true ||
        !context.mounted) {
      return true;
    }
    await prefs?.setBool('$_askedPrefix$alsoKey', true);
    if (!context.mounted) return true;
    final allow = await showAppBottomSheet<bool>(
      context: context,
      builder: (_) =>
          _PermissionSheet(ask: ask, missing: missing, blocked: false),
    );
    if (allow == true) {
      for (final p in missing) {
        await p.request();
      }
    }
    return true;
  }
  final onceKey = ask.onceKey;
  if (onceKey != null && prefs?.getBool('$_askedPrefix$onceKey') == true) {
    return false;
  }
  final blocked = await ask.main.isBlocked();
  if (!context.mounted) return false;

  final allow = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) =>
        _PermissionSheet(ask: ask, missing: missing, blocked: blocked),
  );
  if (onceKey != null) await prefs?.setBool('$_askedPrefix$onceKey', true);
  if (allow != true) return false;
  if (blocked) {
    await openAppSettings();
    // Allowed or not, the caller re-checks when the app comes back.
    return false;
  }
  final granted = await ask.main.request();
  for (final p in missing) {
    if (p != ask.main) await p.request();
  }
  return granted;
}

class _PermissionSheet extends StatelessWidget {
  final PermissionAsk ask;
  final List<AppPermission> missing;
  final bool blocked;

  const _PermissionSheet({
    required this.ask,
    required this.missing,
    required this.blocked,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        AppDimens.space8,
        context.gutter,
        AppDimens.space16 + context.safePadding.bottom,
      ),
      child: PermissionPrompt(
        ask: ask,
        missing: missing,
        blocked: blocked,
        onAllow: () => Navigator.pop(context, true),
        onNotNow: () => Navigator.pop(context, false),
      ),
    );
  }
}

/// The card's content: a large badge, title and reason, one row per
/// permission asked, a privacy line and the buttons. Used in the sheet
/// and inline where a page needs the permission to show anything (the
/// food scanner).
class PermissionPrompt extends StatelessWidget {
  final PermissionAsk ask;
  final List<AppPermission> missing;

  /// The system won't ask again: "Open settings" instead of "Allow".
  final bool blocked;
  final VoidCallback onAllow;
  final VoidCallback? onNotNow;

  /// The second button's words ("Pick from gallery" where there's another
  /// way on without it).
  final String notNowLabel;

  const PermissionPrompt({
    super.key,
    required this.ask,
    required this.missing,
    required this.blocked,
    required this.onAllow,
    this.onNotNow,
    this.notNowLabel = 'Not now',
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    final grey = context.vColors.grayText;
    final rows = missing.isEmpty ? [ask.main] : missing;
    // Only extras missing: lead with the first of them.
    final lead = rows.contains(ask.main) ? ask.main : rows.first;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0.6 : 1, end: 1),
            duration: AppDurations.bounce,
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: _HeroBadge(icon: lead.icon, color: color),
          ),
        ),
        const SizedBox(height: AppDimens.space16),
        Semantics(
          header: true,
          child: Text(
            ask.title,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
        ),
        const SizedBox(height: AppDimens.space8),
        Text(
          blocked
              ? '${ask.message} Turn on ${_names(rows)} in Settings to '
                    'continue.'
              : ask.message,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(color: grey),
        ),
        const SizedBox(height: AppDimens.space16),
        AppCard(
          width: double.infinity,
          padding: AppDimens.cardPaddingCompact,
          child: Column(
            children: [
              for (final (i, p) in rows.indexed) ...[
                if (i > 0) const SizedBox(height: AppDimens.space12),
                _Row(permission: p, index: i, animate: animate),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimens.space12),
        AppInfoNote(icon: Icons.lock_outline_rounded, message: lead.privacy),
        const SizedBox(height: AppDimens.space16),
        AppPrimaryButton(
          label: blocked ? 'Open settings' : 'Allow',
          onTap: onAllow,
        ),
        if (onNotNow case final notNow?) ...[
          const SizedBox(height: AppDimens.space4),
          TextButton(
            onPressed: notNow,
            style: TextButton.styleFrom(foregroundColor: grey),
            child: Text(notNowLabel),
          ),
        ],
      ],
    );
  }

  static String _names(List<AppPermission> permissions) {
    final names = [for (final p in permissions) p.name.toLowerCase()];
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}

/// The permission's icon in a tinted circle inside a soft ring.
class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _HeroBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    const inner = AppDimens.iconXxl + AppDimens.space16;
    return Container(
      padding: const EdgeInsets.all(AppDimens.space8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
      ),
      child: AppIconBadge(
        size: inner,
        color: color,
        icon: Icon(
          icon,
          size: AppDimens.iconXl,
          color: AppIconBadge.glyphColor(context, color),
        ),
      ),
    );
  }
}

/// One permission: icon, name and what it's for. Slides in after the
/// previous one.
class _Row extends StatelessWidget {
  final AppPermission permission;
  final int index;
  final bool animate;

  const _Row({
    required this.permission,
    required this.index,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    final row = Row(
      children: [
        AppIconBadge(
          size: AppDimens.iconBadgeSmall,
          color: color,
          icon: Icon(
            permission.icon,
            size: AppDimens.iconXs,
            color: AppIconBadge.glyphColor(context, color),
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(permission.name, style: context.text.titleSmall),
              Text(
                permission.why,
                style: context.text.bodySmall?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!animate) return row;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.slow + AppDurations.fast * index,
      curve: Interval(
        (index * 0.15).clamp(0.0, 0.6),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * AppDimens.space12),
          child: child,
        ),
      ),
      child: row,
    );
  }
}

/// Records that [onceKey]'s question was already put another way (e.g.
/// onboarding's reminders switch asked for notifications), so its card
/// doesn't ask again.
Future<void> markPermissionAsked(String onceKey) async {
  if (!sl.isRegistered<SharedPreferences>()) return;
  await sl<SharedPreferences>().setBool('$_askedPrefix$onceKey', true);
}

/// Key of Home's notification card.
const homeNotificationsKey = 'home_notifications';

/// Asks once, from Home, for notifications (reminders, workout controls,
/// friends): only when they're off and this card was never answered.
Future<bool> askForNotificationsOnce(BuildContext context) => ensurePermission(
  context,
  const PermissionAsk(
    main: AppPermission.notifications,
    title: 'Stay on track',
    message:
        'Get gentle reminders to drink water, log meals and wind down, '
        'plus news from your friends and challenges.',
    onceKey: homeNotificationsKey,
  ),
);
