import 'package:isar_community/isar.dart';

part 'barcode_cache.g.dart';

@collection
class BarcodeCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String barcode;

  late String productName;
  late String servingSize;
  late double calories;
  late double proteinG;
  late double carbsG;
  late double fatG;
  late double fiberG;
  late double sugarG;
  late double sodiumMg;

  late DateTime cachedAt;
}
