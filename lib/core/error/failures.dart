import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong. Try again.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = "Couldn't load your saved data. Try again."]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = "You're offline. Check your connection."]);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = "Couldn't save on this phone. Try again."]);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Check the details and try again.']);
}

class NoFoodDetectedFailure extends Failure {
  const NoFoodDetectedFailure([super.message = 'No food found. Try a clearer photo.']);
}

class LowConfidenceFailure extends Failure {
  const LowConfidenceFailure([super.message = 'Not sure about this one. Check the items.']);
}

class BarcodeNotFoundFailure extends Failure {
  const BarcodeNotFoundFailure([super.message = 'Barcode not found. Try searching instead.']);
}

class RecognitionUnavailableFailure extends Failure {
  const RecognitionUnavailableFailure([super.message = 'Food scanning is busy. Try again soon.']);
}

class ScanQuotaExceededFailure extends Failure {
  const ScanQuotaExceededFailure([super.message = "No photo scans left today. They reset at midnight."]);
}
