import 'package:supabase_flutter/supabase_flutter.dart';

/// The caller's username and whether they chose it. Google sign-ups start
/// with a generated username that isn't confirmed until they pick one.
class UsernameStatus {
  final String username;
  final bool confirmed;

  const UsernameStatus({required this.username, required this.confirmed});
}

/// A username the server refused, with a message for the user.
class UsernameException implements Exception {
  final String message;

  /// Someone else has it (as opposed to breaking the rules).
  final bool taken;

  const UsernameException(this.message, {this.taken = false});

  @override
  String toString() => message;
}

/// Username rules and the `username_available` / `set_username` RPCs. The
/// server enforces the same rules on every username change.
class UsernameService {
  final SupabaseClient _client;

  UsernameService(this._client);

  static const minLength = 3;
  static const maxLength = 20;
  static final _allowed = RegExp(r'^[A-Za-z0-9._]+$');

  /// Why [username] breaks the rules, or null when it's fine.
  static String? formatError(String username) {
    final value = username.trim();
    if (value.isEmpty) return 'Username is required';
    if (value.length < minLength) return 'Must be at least $minLength characters';
    if (value.length > maxLength) return 'Must be at most $maxLength characters';
    if (!_allowed.hasMatch(value)) {
      return 'Letters, numbers, dots and underscores only';
    }
    return null;
  }

  /// User-facing text for a server error, or null if it isn't a username one.
  static String? messageForServerError(Object error) {
    final text = error is PostgrestException ? error.message : '$error';
    if (text.contains('username_taken')) return 'That username is taken';
    if (text.contains('invalid_username')) {
      return 'Use $minLength-$maxLength letters, numbers, dots or underscores';
    }
    return null;
  }

  /// Null when signed out or the profile doesn't exist yet.
  Future<UsernameStatus?> fetchStatus() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('username, username_confirmed')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UsernameStatus(
      username: row['username'] as String? ?? '',
      confirmed: row['username_confirmed'] as bool? ?? true,
    );
  }

  /// Whether [username] is free for the caller (their own counts as free).
  Future<bool> isAvailable(String username) async =>
      await _client.rpc(
            'username_available',
            params: {'p_username': username.trim()},
          )
          as bool;

  /// Saves and confirms the caller's username. Throws [UsernameException].
  Future<String> setUsername(String username) async {
    final error = formatError(username);
    if (error != null) throw UsernameException(error);
    try {
      return await _client.rpc(
            'set_username',
            params: {'p_username': username.trim()},
          )
          as String;
    } on PostgrestException catch (e) {
      throw UsernameException(
        messageForServerError(e) ?? "Couldn't save your username. Try again.",
        taken: e.message.contains('username_taken'),
      );
    }
  }
}
