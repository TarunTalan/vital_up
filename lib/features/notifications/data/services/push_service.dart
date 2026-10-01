import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';
import 'package:vital_up/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';

/// Pushes are shown by the system while the app is in the background; this
/// only needs to exist so FCM can wake the app.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {}

/// A tapped push: which notification, and what it links to.
class PushOpen {
  final int? notificationId;
  final NotificationType type;
  final String? route;

  const PushOpen({required this.type, this.notificationId, this.route});

  factory PushOpen.fromData(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    return PushOpen(
      notificationId: int.tryParse('${data['notification_id']}'),
      type: NotificationType.fromCode(data['type'] as String?),
      route: route == null || route.isEmpty ? null : route,
    );
  }
}

/// FCM push notifications: keeps this device's token registered for the
/// signed-in user, shows pushes that arrive while the app is open, and
/// reports taps (pushes and reminders) through [opens] / [takePendingOpen].
///
/// A no-op until Firebase is configured (no `google-services.json`).
class PushService {
  final SupabaseClient _client;
  final SettingsRepository _settings;
  final NotificationsRepository _notifications;

  /// Shared with ReminderScheduler; initialised here.
  final FlutterLocalNotificationsPlugin _local;

  PushService(this._client, this._settings, this._notifications, this._local);

  /// Must match the channel in AndroidManifest.xml and send-push.
  static const _channel = AndroidNotificationChannel(
    'vitalup_general',
    'Notifications',
    description: 'Friend requests, achievements and updates',
    importance: Importance.high,
  );

  final _opens = StreamController<PushOpen>.broadcast();
  PushOpen? _pending;
  bool _ready = false;
  String? _registeredToken;

  /// Taps while the app is running.
  Stream<PushOpen> get opens => _opens.stream;

  /// The push that launched the app, once. Read when the home screen opens.
  PushOpen? takePendingOpen() {
    final open = _pending;
    _pending = null;
    return open;
  }

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Call once at startup, after Supabase is initialised.
  Future<void> init() async {
    // Local notifications (reminders, foreground pushes) work without
    // Firebase, so set them up first.
    await _initLocal();

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Push disabled, Firebase is not configured: $e');
      return;
    }
    _ready = true;
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    final messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleOpen(m.data));
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleOpen(initial.data);

    messaging.onTokenRefresh.listen((_) => register());
    _client.auth.onAuthStateChange.listen((auth) {
      final signedIn = auth.session != null;
      if (signedIn &&
          (auth.event == AuthChangeEvent.initialSession ||
              auth.event == AuthChangeEvent.signedIn)) {
        register();
      }
    });
  }

  Future<void> _initLocal() async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is asked for when push or a reminder is turned on.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _handlePayload(response.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      // A local notification (e.g. a reminder) that launched the app.
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _handlePayload(launch!.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('Local notifications unavailable: $e');
    }
  }

  void _handlePayload(String? payload) {
    if (payload == null) return;
    try {
      _handleOpen(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (_) {}
  }

  /// Asks for notification permission (Android 13+), then registers.
  /// Called when the home screen opens.
  Future<void> requestPermissionAndRegister() async {
    if (!_ready || !await _enabledInSettings()) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('Push permission request failed: $e');
    }
    await register();
  }

  /// Saves this device's token for the signed-in user, if allowed.
  Future<void> register() async {
    if (!_ready || _client.auth.currentUser == null) return;
    if (!await _enabledInSettings()) return;
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _client.rpc(
        'register_push_token',
        params: {'p_token': token, 'p_platform': _platform},
      );
      _registeredToken = token;
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }

  /// Stops pushes to this device for the current user. Call before signing
  /// out (the request needs the session) or when notifications are turned
  /// off in settings.
  Future<void> unregister() async {
    if (!_ready || _client.auth.currentUser == null) return;
    try {
      final token =
          _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _client.rpc('unregister_push_token', params: {'p_token': token});
      _registeredToken = null;
    } catch (e) {
      debugPrint('Push token removal failed: $e');
    }
  }

  /// Follows the notifications switch in settings.
  Future<void> setEnabled(bool enabled) =>
      enabled ? requestPermissionAndRegister() : unregister();

  Future<bool> _enabledInSettings() async {
    final result = await _settings.getSettings();
    return result.fold((_) => true, (s) => s.notificationsEnabled);
  }

  /// The system doesn't show pushes while the app is open, so show it here.
  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final id = int.tryParse('${message.data['notification_id']}');
    await _local.show(
      id: id ?? message.hashCode,
      title: n.title,
      body: n.body,
      payload: jsonEncode(message.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _handleOpen(Map<String, dynamic> data) {
    final open = PushOpen.fromData(data);
    final id = open.notificationId;
    if (id != null) {
      _notifications.markRead([id]).catchError(
        (Object e) => debugPrint('Mark push read failed: $e'),
      );
    }
    if (_opens.hasListener) {
      _opens.add(open);
    } else {
      _pending = open;
    }
  }
}
