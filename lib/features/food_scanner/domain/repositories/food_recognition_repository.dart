import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'dart:io';

abstract class FoodRecognitionRepository {
  Future<Either<Failure, List<FoodItem>>> recognizeFood(File image);
  
  Future<Either<Failure, List<FoodItem>>> searchByName(String query);
}
