import 'dart:convert';

/// Cache keys for food-scanner server reads stored in `CacheStore`.
///
/// Nutrition facts are shared data (no user id); subscription state is
/// personal and keyed per user.
class FoodCacheKeys {
  FoodCacheKeys._();

  /// Bump when a cached payload's shape changes.
  static const _v = 'v1';

  static String nutrition(String id, String name, String serving) =>
      'food:nutrition:$_v:${hashString('${normalizeFoodQuery(id)}|${normalizeFoodQuery(name)}|${normalizeFoodQuery(serving)}')}';

  static String search(String query) => 'food:search:$_v:${hashString(normalizeFoodQuery(query))}';

  static String recognition(String imageHash) => 'food:recognition:$_v:$imageHash';

  static String premium(String userId) => 'subscription:premium:$_v:$userId';

  static String remainingScans(String userId) => 'subscription:remaining_scans:$_v:$userId';
}

/// Lowercase, trimmed, single-spaced, so "Dal  Tadka " and "dal tadka" share
/// one cache entry.
String normalizeFoodQuery(String query) => query.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// 64-bit FNV-1a of [bytes] as hex. Not cryptographic; only used to name
/// cache entries, where a collision would at worst return another scan's
/// cached result. Written out because `crypto` is not a direct dependency.
String hashBytes(List<int> bytes) {
  var h = (0xcbf29ce4 << 32) | 0x84222325;
  for (final b in bytes) {
    h ^= b;
    // h * 0x100000001b3, wrapping at 64 bits.
    h = (h << 40) + h * 0x1b3;
  }
  // Two halves: a 64-bit Dart int is signed, so one toRadixString may print '-'.
  String hex32(int v) => (v & 0xffffffff).toRadixString(16).padLeft(8, '0');
  return hex32(h >> 32) + hex32(h);
}

/// Hashed rather than embedded so long or non-ASCII queries still make
/// short file names.
String hashString(String value) => hashBytes(utf8.encode(value));
