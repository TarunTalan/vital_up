import 'dart:async';

/// Longest a screen or card waits for its data before giving up and showing
/// an error (with retry) instead of spinning forever.
const Duration kLoadTimeout = Duration(seconds: 15);

/// Budget for one optional source inside a load (a Health Connect read,
/// screen-time query…). On timeout the load carries on without it.
const Duration kSourceTimeout = Duration(seconds: 8);

/// Shown when a load fails or times out.
const String kLoadErrorMessage = "Couldn't load this right now.";

extension LoadTimeout<T> on Future<T> {
  /// Throws [TimeoutException] after [limit].
  Future<T> withLoadTimeout([Duration limit = kLoadTimeout]) => timeout(limit);

  /// Completes with [fallback] if this fails or takes longer than [limit],
  /// for sources that are nice to have but must never block a screen.
  Future<T> orFallback(T fallback, [Duration limit = kSourceTimeout]) =>
      timeout(limit, onTimeout: () => fallback).catchError((_) => fallback);
}
