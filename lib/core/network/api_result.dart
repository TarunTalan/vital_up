import 'dart:io';
import 'package:dio/dio.dart';

abstract class ApiResult<T> {
  const ApiResult();
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiError<T> extends ApiResult<T> {
  final String message;
  final int code;
  const ApiError({required this.message, required this.code});
}

class ResponseHandler {
  ResponseHandler._();

  static ApiResult<T> handleResponse<T>(Response<T> response) {
    if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
      final body = response.data;
      if (body != null) {
        return ApiSuccess(body);
      } else {
        return ApiError(message: 'Empty response', code: response.statusCode!);
      }
    } else {
      final message = mapCodeToMessage(response.statusCode ?? 0);
      return ApiError(message: message, code: response.statusCode ?? 0);
    }
  }

  static ApiResult<Never> fromException(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.error is SocketException) {
        return const ApiError(message: 'Network error. Please check your connection.', code: -1);
      }
      final statusCode = e.response?.statusCode ?? -1;
      final serverMessage = e.response?.data?['message']?.toString();
      final message = serverMessage ?? mapCodeToMessage(statusCode);
      return ApiError(message: message, code: statusCode);
    } else if (e is IOException) {
      return const ApiError(message: 'Network error. Please check your connection.', code: -1);
    } else {
      return ApiError(message: e.toString(), code: -1);
    }
  }

  static String mapCodeToMessage(int code) {
    if (code == 400) {
      return 'Bad request';
    } else if (code == 401) {
      return 'Unauthorized. Please sign in again.';
    } else if (code == 403) {
      return 'Access denied';
    } else if (code == 404) {
      return 'Resource not found';
    } else if (code == 422) {
      return 'Invalid input';
    } else if (code == 429) {
      return 'Too many requests. Try again later.';
    } else if (code >= 500 && code <= 599) {
      return 'Server error. Please try again later.';
    } else {
      return 'An unexpected error occurred';
    }
  }
}
