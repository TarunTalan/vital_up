import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';

class ScanBarcode {
  final NutritionRepository nutritionRepository;

  ScanBarcode({required this.nutritionRepository});

  Future<Either<Failure, NutritionInfo>> call(String barcode) async {
    return await nutritionRepository.lookupBarcode(barcode);
  }
}
