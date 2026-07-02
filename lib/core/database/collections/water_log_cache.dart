import 'package:isar_community/isar.dart';

part 'water_log_cache.g.dart';

@collection
class WaterLogCache {
  Id id = Isar.autoIncrement;

  @Index()
  late String userId;

  late int amountMl;
  
  @Index()
  late DateTime timestamp;
  
  bool isSynced = false;
}
