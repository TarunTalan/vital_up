import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scan/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scan/domain/repositories/nutrition_repository.dart';

class ScanBarcode {
  final NutritionRepository nutritionRepository;

  ScanBarcode({required this.nutritionRepository});

  Future<Either<Failure, FoodItem>> call(String barcode) async {
    return await nutritionRepository.lookupBarcode(barcode);
  }
}
