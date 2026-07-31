import 'package:isar_community/isar.dart';

part 'offline_food.g.dart';

@collection
class OfflineFood {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name;

  late String servingSize;
  late double calories;
  late double proteinG;
  late double carbsG;
  late double fatG;
  late double fiberG;
  late double sugarG;
  late double sodiumMg;
}
