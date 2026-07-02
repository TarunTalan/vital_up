import 'package:isar_community/isar.dart';

part 'heart_rate_log_cache.g.dart';

@collection
class HeartRateLogCache {
  Id id = Isar.autoIncrement;

  @Index()
  late String userId;

  late int bpm;
  
  @Index()
  late DateTime timestamp;
  
  bool isSynced = false;
}
