import 'package:isar_community/isar.dart';

part 'weight_log_cache.g.dart';

/// One body-weight entry, always in kilograms.
@collection
class WeightLogCache {
  Id id = Isar.autoIncrement;

  @Index()
  late String userId;

  late double weightKg;

  @Index()
  late DateTime timestamp;

  /// 'manual' or 'health' (imported from Health Connect / Apple Health).
  String source = 'manual';

  bool isSynced = false;
}
