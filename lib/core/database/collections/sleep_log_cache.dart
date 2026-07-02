import 'package:isar_community/isar.dart';

part 'sleep_log_cache.g.dart';

@collection
class SleepLogCache {
  Id id = Isar.autoIncrement;

  @Index()
  late String userId;

  late DateTime startTime;
  late DateTime endTime;
  
  late int durationMinutes;
  
  bool isSynced = false;
}
