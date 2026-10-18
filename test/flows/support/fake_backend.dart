// The server stand-in speaks HTTP to the real Supabase client, so it needs
// `http` (a dependency of supabase_flutter) directly.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory stand-in for the Supabase REST API (PostgREST + the auth
/// logout call), reached through the real [SupabaseClient] via [client].
///
/// Mirrors what the app relies on from the real backend:
/// - row level security: a request only sees and writes rows of the user in
///   its access token (`user_id`, or `id` for `user_health_data`);
/// - `updated_at` is set by the server on every write (the pull cursor);
/// - `user_backups` keeps the row with the newest `changed_at`;
/// - a CHECK violation ([reject]) fails the whole request, like Postgres.
class FakeBackend {
  final tables = <String, Map<String, Map<String, dynamic>>>{};

  /// Every request: `METHOD table` (e.g. `POST water_logs`, `RPC set_x`).
  final requests = <String>[];

  /// Return a Postgres error code (e.g. '23514') to refuse a written row.
  String? Function(String table, Map<String, dynamic> row)? reject;

  /// Answers every request to [table] with this PostgREST error code
  /// (e.g. 'PGRST303' for an expired token) while set.
  final failTable = <String, String>{};

  /// Handlers for `rpc/<name>`; unknown functions return null.
  final rpcs = <String, Object? Function(String? userId, Map params)>{};

  /// While set, requests never answer (to test timeouts).
  Completer<void>? hang;

  /// While true, every request fails like a dropped connection.
  bool offline = false;

  DateTime _clock = DateTime.now().toUtc();

  late final http.Client client = MockClient((request) async {
    final response = await _handle(request);
    // PostgREST's client reads the request back from the response.
    return http.Response(
      response.body,
      response.statusCode,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  });

  /// A Supabase client for one device, talking to this backend.
  SupabaseClient newClient() => SupabaseClient(
    'https://backend.test',
    'publishable-key',
    httpClient: client,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );

  List<Map<String, dynamic>> rows(String table) => [...?tables[table]?.values];

  /// Rows of [table] not soft-deleted.
  List<Map<String, dynamic>> live(String table) =>
      rows(table).where((r) => r['deleted_at'] == null).toList();

  int count(String request) => requests.where((r) => r == request).length;

  String _now() {
    // Strictly increasing, like separate transactions.
    _clock = _clock.add(const Duration(milliseconds: 1));
    return _clock.toIso8601String();
  }

  Future<http.Response> _handle(http.Request request) async {
    if (offline) throw const SocketException('Connection refused');
    if (hang != null) await hang!.future;
    final segments = request.url.pathSegments;
    if (segments.length >= 2 && segments[0] == 'auth') {
      requests.add('AUTH ${segments.last}');
      return http.Response('', 204);
    }
    if (segments.length < 3 || segments[0] != 'rest') {
      return _error(404, 'PGRST000', 'unknown path ${request.url.path}');
    }
    final userId = _userFrom(request.headers['Authorization']);
    if (segments[2] == 'rpc') {
      final name = segments[3];
      requests.add('RPC $name');
      final failure = failTable[name];
      if (failure != null) return _error(401, failure, 'refused');
      final params = request.body.isEmpty
          ? const {}
          : jsonDecode(request.body) as Map;
      final result = rpcs[name]?.call(userId, params);
      return http.Response(jsonEncode(result), 200);
    }
    final table = segments[2];
    requests.add('${request.method} $table');
    final failure = failTable[table];
    if (failure != null) {
      return _error(failure.startsWith('PGRST3') ? 401 : 400, failure, 'no');
    }
    final store = tables.putIfAbsent(table, () => {});
    final owner = table == 'user_health_data' ? 'id' : 'user_id';
    final filters = _Filters.parse(request.url.queryParametersAll);
    bool visible(Map<String, dynamic> row) =>
        userId != null && '${row[owner]}' == userId;

    switch (request.method) {
      case 'GET':
        var result = store.values
            .where(visible)
            .where(filters.matches)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        result = filters.sortAndLimit(result);
        return http.Response(jsonEncode(result), 200);
      case 'POST':
        final body = jsonDecode(request.body);
        final list = [
          for (final r in body is List ? body : [body])
            Map<String, dynamic>.from(r as Map),
        ];
        for (final row in list) {
          if ('${row[owner]}' != userId) {
            return _error(403, '42501', 'row violates row-level security');
          }
          final code = reject?.call(table, row);
          if (code != null) return _error(400, code, 'violates check');
        }
        final key = request.url.queryParameters['on_conflict'] ?? 'id';
        for (final row in list) {
          final id = '${row[key]}';
          final old = store[id];
          if (table == 'user_backups' &&
              old != null &&
              !DateTime.parse(
                row['changed_at'] as String,
              ).isAfter(DateTime.parse(old['changed_at'] as String))) {
            continue; // Last writer wins (trigger skips the update).
          }
          store[id] = {
            ...?old,
            ...row,
            'created_at': old?['created_at'] ?? _now(),
            'updated_at': _now(),
          };
        }
        return http.Response('', 201);
      case 'PATCH':
        final values = jsonDecode(request.body) as Map;
        for (final row in store.values.where(visible).where(filters.matches)) {
          row.addAll(Map<String, dynamic>.from(values));
          row['updated_at'] = _now();
        }
        return http.Response('', 204);
      case 'DELETE':
        store.removeWhere((_, row) => visible(row) && filters.matches(row));
        return http.Response('', 204);
    }
    return _error(405, 'PGRST000', 'method');
  }

  static http.Response _error(int status, String code, String message) =>
      http.Response(
        jsonEncode({'code': code, 'message': message, 'details': null}),
        status,
      );

  /// The `sub` of a bearer token made by [accessToken].
  static String? _userFrom(String? header) {
    final token = header?.replaceFirst('Bearer ', '');
    final parts = token?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// A token the client accepts as unexpired, carrying [userId].
  static String accessToken(String userId) {
    String part(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${part({'sub': userId, 'role': 'authenticated', 'exp': 4102444800})}'
        '.signature';
  }

  /// Signs [client] in as [userId] without a network round trip.
  static Future<void> signIn(SupabaseClient client, String userId) async {
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': accessToken(userId),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-$userId',
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'email': '$userId@example.com',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
        },
      }),
    );
  }
}

/// The PostgREST filters, ordering and limit the app's queries use.
class _Filters {
  final List<bool Function(Map<String, dynamic>)> _tests;
  final List<(String, bool)> _order;
  final int? _limit;

  _Filters(this._tests, this._order, this._limit);

  static const _reserved = {
    'select',
    'order',
    'limit',
    'on_conflict',
    'or',
    'columns',
  };

  factory _Filters.parse(Map<String, List<String>> query) {
    final tests = <bool Function(Map<String, dynamic>)>[];
    for (final entry in query.entries) {
      if (_reserved.contains(entry.key)) continue;
      for (final value in entry.value) {
        tests.add(_condition(entry.key, value));
      }
    }
    for (final or in query['or'] ?? const <String>[]) {
      tests.add(_group(or.substring(1, or.length - 1), any: true));
    }
    final order = <(String, bool)>[
      for (final o in (query['order']?.first ?? '').split(','))
        if (o.isNotEmpty) (o.split('.')[0], o.split('.')[1] != 'desc'),
    ];
    final limit = int.tryParse(query['limit']?.first ?? '');
    return _Filters(tests, order, limit);
  }

  bool matches(Map<String, dynamic> row) => _tests.every((t) => t(row));

  List<Map<String, dynamic>> sortAndLimit(List<Map<String, dynamic>> rows) {
    rows.sort((a, b) {
      for (final (column, ascending) in _order) {
        final c = _compare(column, a[column], b[column]);
        if (c != 0) return ascending ? c : -c;
      }
      return 0;
    });
    return _limit == null ? rows : rows.take(_limit).toList();
  }

  /// `a.gt."x",and(b.eq."y",c.gt."z")` combined with or / and.
  static bool Function(Map<String, dynamic>) _group(
    String body, {
    required bool any,
  }) {
    final parts = <String>[];
    var depth = 0, quoted = false, start = 0;
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (ch == '"') quoted = !quoted;
      if (quoted) continue;
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        parts.add(body.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(body.substring(start));
    final tests = [
      for (final p in parts)
        if (p.startsWith('and('))
          _group(p.substring(4, p.length - 1), any: false)
        else if (p.startsWith('or('))
          _group(p.substring(3, p.length - 1), any: true)
        else
          _condition(
            p.substring(0, p.indexOf('.')),
            p.substring(p.indexOf('.') + 1),
          ),
    ];
    return any
        ? (row) => tests.any((t) => t(row))
        : (row) => tests.every((t) => t(row));
  }

  static bool Function(Map<String, dynamic>) _condition(
    String column,
    String expression,
  ) {
    final dot = expression.indexOf('.');
    final op = expression.substring(0, dot);
    var value = expression.substring(dot + 1);
    if (value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    return (row) {
      final actual = row[column];
      if (op == 'is') return value == 'null' ? actual == null : actual != null;
      if (actual == null) return false;
      final c = _compare(column, actual, value);
      return switch (op) {
        'eq' => c == 0,
        'neq' => c != 0,
        'gt' => c > 0,
        'gte' => c >= 0,
        'lt' => c < 0,
        'lte' => c <= 0,
        _ => throw UnsupportedError('filter $op'),
      };
    };
  }

  static int _compare(String column, Object? a, Object? b) {
    if (a == null || b == null) return a == b ? 0 : (a == null ? 1 : -1);
    if (column.endsWith('_at') || column.endsWith('_time')) {
      final x = DateTime.tryParse('$a'), y = DateTime.tryParse('$b');
      if (x != null && y != null) return x.compareTo(y);
    }
    if (a is num && b is num) return a.compareTo(b);
    final na = num.tryParse('$a'), nb = num.tryParse('$b');
    if (a is num && nb != null) return a.compareTo(nb);
    if (na != null && b is num) return na.compareTo(b);
    return '$a'.compareTo('$b');
  }
}
