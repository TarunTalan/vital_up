import 'package:isar_community/isar.dart';

part 'user_profile_cache.g.dart';

@collection
class UserProfileCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String supabaseId;

  late String username;
  late String email;
  String? displayName;
  String? photoUrl;

  double? weightKg;

  // Health goals (set during onboarding)
  int? dailyCalorieGoal;
  double? targetWeightKg;
  int? goalDurationMonths;
  DateTime? lastSyncedAt;
}
