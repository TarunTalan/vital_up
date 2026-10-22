import 'package:go_router/go_router.dart';

/// What each location was opened with, so a page keeps its `extra`.
///
/// go_router rebuilds a pushed page without its `extra` when it runs its
/// redirects again (seen when the system switches light / dark mode while
/// a leaderboard is open: "This page isn't available"). Every `extra` read
/// in the router goes through [routeExtra], which remembers the last one
/// seen for the location and hands it back when the rebuild comes empty.
final Map<String, Object> _byLocation = {};

/// [state]'s `extra`, or the one its location was last opened with.
Object? routeExtra(GoRouterState state) {
  final key = state.uri.toString();
  final extra = state.extra;
  if (extra != null) {
    _byLocation[key] = extra;
    return extra;
  }
  return _byLocation[key];
}

/// Forgets every remembered `extra` (sign-out: the next account must not
/// reopen a page with the last one's data).
void clearRouteExtras() => _byLocation.clear();
