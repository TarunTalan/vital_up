import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/database/collections/offline_food.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

abstract class NutritionRepository {
  Future<Either<Failure, NutritionInfo>> getNutrition(FoodItem item);
  
  Future<Either<Failure, NutritionInfo>> lookupBarcode(String barcode);
  
  Future<Either<Failure, List<FoodItem>>> searchByName(String query);

  Future<Either<Failure, void>> saveProprietaryProduct(
    String barcode,
    String productName,
    NutritionInfo nutrition,
    String source,
  );

  /// Search the local offline Isar database of pre-seeded popular Indian foods.
  /// Returns matching [OfflineFood] entries sorted by best name match.
  Future<List<OfflineFood>> searchOfflineFoods(String query);
}

