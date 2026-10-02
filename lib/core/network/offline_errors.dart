import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// True when [error] means the server couldn't be reached (no network,
/// DNS failure, dropped connection, timeout) rather than that it answered
/// with an error. Such failures are worth retrying later; others aren't.
bool isOfflineError(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is HandshakeException) {
    return true;
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        return error.error != null && isOfflineError(error.error!);
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return false;
    }
  }
  // Supabase wraps transport errors (http ClientException,
  // AuthRetryableFetchException, FunctionException with status 0) so the
  // message is the only common signal.
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('connection closed') ||
      text.contains('connection failed') ||
      text.contains('connection timed out') ||
      text.contains('network is unreachable') ||
      text.contains('no address associated') ||
      text.contains('retryablefetchexception') ||
      text.contains('timeoutexception') ||
      text.contains('handshake');
}
