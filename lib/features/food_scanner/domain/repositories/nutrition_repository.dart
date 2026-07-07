import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

abstract class NutritionRepository {
  Future<Either<Failure, NutritionInfo>> getNutrition(FoodItem item);
  
  Future<Either<Failure, FoodItem>> lookupBarcode(String barcode);
  
  Future<Either<Failure, List<FoodItem>>> searchByName(String query);
}
