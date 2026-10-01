import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Interceptor that retries failed Dio requests with exponential backoff and jitter.
///
/// Designed to gracefully handle intermittent network drops when users are
/// jogging, commuting, or in low-connectivity areas.
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final Logger? logger;
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Random _random = Random();

  static const String retryCountKey = 'vitalup_retry_count';

  RetryInterceptor({
    required this.dio,
    this.logger,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 1000),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final extra = err.requestOptions.extra;
    final currentAttempt = (extra[retryCountKey] as int? ?? 0);

    if (!_shouldRetry(err) || currentAttempt >= maxRetries) {
      return handler.next(err);
    }

    final nextAttempt = currentAttempt + 1;
    final delay = _calculateDelay(nextAttempt);

    logger?.w(
      'RetryInterceptor: [Attempt $nextAttempt/$maxRetries] Retrying ${err.requestOptions.path} in ${delay.inMilliseconds}ms due to: ${err.message ?? err.type.name}',
    );

    await Future<void>.delayed(delay);

    try {
      final updatedOptions = err.requestOptions;
      updatedOptions.extra[retryCountKey] = nextAttempt;

      final response = await dio.fetch(updatedOptions);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (e) {
      return handler.next(err);
    }
  }

  /// Evaluates whether an error should be retried.
  bool _shouldRetry(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == null) return false;
        // 408 Request Timeout, 429 Rate Limit, 500, 502 Bad Gateway, 503 Unavailable, 504 Gateway Timeout
        return status == 408 ||
            status == 429 ||
            status == 500 ||
            status == 502 ||
            status == 503 ||
            status == 504;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        final message = error.message?.toLowerCase() ?? '';
        return message.contains('socketexception') ||
            message.contains('connection') ||
            message.contains('handshakeexception');
    }
  }

  /// Computes exponential backoff with full jitter to avoid thundering herd.
  Duration _calculateDelay(int attempt) {
    final exponentialMs =
        initialDelay.inMilliseconds * pow(backoffMultiplier, attempt - 1);
    final cappedMs = min(exponentialMs, maxDelay.inMilliseconds.toDouble());
    // Apply jitter between 75% and 125% of calculated delay
    final jitterFactor = 0.75 + (_random.nextDouble() * 0.50);
    final finalMs = (cappedMs * jitterFactor).round();
    return Duration(milliseconds: max(100, finalMs));
  }
}
