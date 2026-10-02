import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/domain/entities/recognized_food.dart';
import 'dart:io';

abstract class FoodRecognitionRepository {
  Future<Either<Failure, List<RecognizedFood>>> recognizeFood(File image);
}
