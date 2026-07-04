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
