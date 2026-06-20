import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([String message = 'A server error occurred. Please try again later.']) : super(message);
}

class CacheFailure extends Failure {
  const CacheFailure([String message = 'Failed to load local data.']) : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection. Please check your network settings.']) : super(message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([String message = 'Local database operation failed.']) : super(message);
}

class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Invalid input details provided.']) : super(message);
}
