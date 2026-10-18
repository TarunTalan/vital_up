import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Central coordinator for loading states and active API calls across the entire app.
///
/// When any loading token is active or any API request is in-flight,
/// [isLoading] is true, signaling the app to make screens un-interactive.
class AppLoadingController extends ChangeNotifier {
  AppLoadingController._();

  static final AppLoadingController instance = AppLoadingController._();

  final Set<Object> _loadingTokens = <Object>{};
  int _activeRequests = 0;
  Timer? _safetyWatchdog;

  /// Maximum time (in seconds) the screen is permitted to remain locked
  /// consecutively before the safety watchdog unlocks the UI.
  static const int _safetyTimeoutSeconds = 30;

  /// True if any page, button, or API call is currently in a loading/busy state.
  bool get isLoading => _loadingTokens.isNotEmpty || _activeRequests > 0;

  /// Number of active loading operations.
  int get activeOperationsCount => _loadingTokens.length + _activeRequests;

  /// Registers a manual loading token.
  void startLoading([Object? token]) {
    final key = token ?? Object();
    _loadingTokens.add(key);
    _armSafetyWatchdog();
    _notifySafely();
  }

  /// Removes a manual loading token.
  void stopLoading([Object? token]) {
    if (token != null) {
      _loadingTokens.remove(token);
    } else if (_loadingTokens.isNotEmpty) {
      _loadingTokens.remove(_loadingTokens.first);
    }
    _checkDisarmSafetyWatchdog();
    _notifySafely();
  }

  /// Sets loading state for a specific token (e.g. a widget instance).
  void setTokenLoading(Object token, bool loading) {
    if (loading) {
      _loadingTokens.add(token);
      _armSafetyWatchdog();
    } else {
      _loadingTokens.remove(token);
      _checkDisarmSafetyWatchdog();
    }
    _notifySafely();
  }

  /// Increments active API request count.
  void startRequest() {
    _activeRequests++;
    _armSafetyWatchdog();
    _notifySafely();
  }

  /// Decrements active API request count.
  void endRequest() {
    if (_activeRequests > 0) {
      _activeRequests--;
    }
    _checkDisarmSafetyWatchdog();
    _notifySafely();
  }

  /// Wraps an asynchronous task, making the app un-interactive until completed.
  Future<T> track<T>(Future<T> Function() action) async {
    final token = Object();
    startLoading(token);
    try {
      return await action();
    } finally {
      stopLoading(token);
    }
  }

  /// Resets all loading states. Useful in tests or error recoveries.
  void reset() {
    _loadingTokens.clear();
    _activeRequests = 0;
    _safetyWatchdog?.cancel();
    _safetyWatchdog = null;
    _notifySafely();
  }

  void _armSafetyWatchdog() {
    if (_safetyWatchdog == null || !_safetyWatchdog!.isActive) {
      _safetyWatchdog?.cancel();
      _safetyWatchdog = Timer(
        const Duration(seconds: _safetyTimeoutSeconds),
        () {
          if (isLoading) {
            debugPrint(
              'AppLoadingController: Safety watchdog triggered after '
              '$_safetyTimeoutSeconds seconds. Auto-clearing un-interactive state.',
            );
            reset();
          }
        },
      );
    }
  }

  void _checkDisarmSafetyWatchdog() {
    if (!isLoading) {
      _safetyWatchdog?.cancel();
      _safetyWatchdog = null;
    }
  }

  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}
