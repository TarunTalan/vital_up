import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the app can reach the network.
///
/// Combines two signals:
/// - the OS network interface (wifi / mobile / ethernet) from
///   `connectivity_plus`, which only says a network *exists*;
/// - real request outcomes reported via [reportFailure] / [reportSuccess],
///   which catch captive portals and dead links the OS still calls online.
///
/// [onlineChanges] fires `true` whenever the app goes from offline back to
/// online, which is when queued work should be flushed.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final _changes = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _hasInterface = true;
  bool _reachable = true;

  /// A network interface is up. Cheap check before attempting requests.
  bool get hasNetwork => _hasInterface;

  /// Network is up and the last request didn't fail for lack of it.
  bool get isOnline => _hasInterface && _reachable;

  /// Emits the new [isOnline] value each time it flips.
  Stream<bool> get onlineChanges => _changes.stream;

  Future<void> init() async {
    if (_sub != null) return; // Already listening.
    try {
      _hasInterface = _isConnected(await _connectivity.checkConnectivity());
    } catch (e) {
      debugPrint('ConnectivityService: initial check failed: $e');
    }
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = isOnline;
      _hasInterface = _isConnected(results);
      // A new network gets a fresh chance even if the last one was dead.
      if (_hasInterface) _reachable = true;
      _emitIfChanged(wasOnline);
    });
  }

  /// A request just failed because the network was unavailable.
  void reportFailure() {
    final wasOnline = isOnline;
    _reachable = false;
    _emitIfChanged(wasOnline);
  }

  /// A request just reached the server.
  void reportSuccess() {
    final wasOnline = isOnline;
    _reachable = true;
    _emitIfChanged(wasOnline);
  }

  void _emitIfChanged(bool wasOnline) {
    if (wasOnline != isOnline && !_changes.isClosed) _changes.add(isOnline);
  }

  static bool _isConnected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void dispose() {
    _sub?.cancel();
    _changes.close();
  }
}
