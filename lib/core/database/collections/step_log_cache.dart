import 'package:isar_community/isar.dart';

part 'step_log_cache.g.dart';

@collection
class StepLogCache {
  Id id = Isar.autoIncrement;

  @Index()
  late String userId;

  late int steps;
  
  @Index()
  late DateTime date;
  
  bool isSynced = false;
  
  DateTime? createdAt;
}
