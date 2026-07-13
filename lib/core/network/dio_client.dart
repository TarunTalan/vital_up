import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class DioClient {
  final Dio _dio;
  final Logger _logger;

  DioClient({
    required this._dio,
    required this._logger,
  }) {
    _setupInterceptors();
  }

  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.options = BaseOptions(
      // Configure with vitalup dev backend endpoint
      baseUrl: 'https://vitalup.dev/api/v1/', 
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Read secure JWT token directly from Supabase session (it handles refreshing natively)
          final token = Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          _logger.i('Request: [${options.method}] ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.i('Response: [${response.statusCode}] ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          _logger.e('Error: [${error.response?.statusCode}] ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  // HTTP Helper methods mapping standard REST operations
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters, options: options);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(path, data: data, queryParameters: queryParameters, options: options);
    } catch (e) {
      rethrow;
    }
  }
}
