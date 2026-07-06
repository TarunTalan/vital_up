import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'A server error occurred. Please try again later.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Failed to load local data.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection. Please check your network settings.']);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Local database operation failed.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid input details provided.']);
}

class NoFoodDetectedFailure extends Failure {
  const NoFoodDetectedFailure([super.message = 'No food was detected in the image. Please try again with a clearer photo.']);
}

class LowConfidenceFailure extends Failure {
  const LowConfidenceFailure([super.message = 'Food recognition confidence is low. Please review and confirm the detected items.']);
}

class BarcodeNotFoundFailure extends Failure {
  const BarcodeNotFoundFailure([super.message = 'Barcode not found in database. Please try manual search.']);
}
