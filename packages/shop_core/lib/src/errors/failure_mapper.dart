import 'package:dio/dio.dart';

import 'app_failure.dart';

/// Turns a failed HTTP call into an [AppFailure]. The only place that knows
/// the backend's error codes.
AppFailure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkFailure(
          'The server took too long to respond. Please try again.');
    case DioExceptionType.connectionError:
      return const NetworkFailure(
          'Cannot reach the server. Check your connection.');
    default:
      break;
  }

  final response = e.response;
  if (response == null) {
    return const NetworkFailure('Something went wrong. Please try again.');
  }
  return mapErrorResponse(response.statusCode ?? 0, response.data,
      retryAfterHeader: response.headers.value('retry-after'));
}

AppFailure mapErrorResponse(int status, Object? body,
    {String? retryAfterHeader}) {
  String code = '';
  String message = '';
  Map<String, dynamic> details = const {};

  if (body is Map && body['error'] is Map) {
    final error = (body['error'] as Map).cast<String, dynamic>();
    code = (error['code'] ?? '').toString();
    message = (error['message'] ?? '').toString();
    if (error['details'] is Map) {
      details = (error['details'] as Map).cast<String, dynamic>();
    }
  }

  switch (code) {
    case 'VALIDATION_FAILED':
      return ValidationFailure(
        message.isEmpty ? 'Please check the highlighted fields.' : message,
        _fieldErrors(details),
      );
    case 'INVALID_CREDENTIALS':
      return const InvalidCredentialsFailure('Wrong email or password.');
    case 'UNAUTHENTICATED':
    case 'INVALID_TOKEN':
      return const UnauthenticatedFailure(
          'Your session has expired. Please sign in again.');
    case 'FORBIDDEN':
      return const ForbiddenFailure(
          'You are not allowed to do this.');
    case 'NOT_FOUND':
      return NotFoundFailure(message.isEmpty ? 'Not found.' : message);
    case 'INSUFFICIENT_STOCK':
      return InsufficientStockFailure(
        'Some items are no longer available in the requested quantity.',
        _stockProblems(details),
      );
    case 'INVALID_STATUS_TRANSITION':
      return InvalidTransitionFailure(
        'This status change is not allowed.',
        current: details['current']?.toString(),
        allowed: [
          for (final s in (details['allowed'] as List? ?? const [])) s.toString()
        ],
      );
    case 'TOO_MANY_REQUESTS':
      return RateLimitedFailure(
        'Too many attempts. Please wait a moment and try again.',
        retryAfter: _seconds(retryAfterHeader),
      );
    case 'INVENTORY_UNAVAILABLE':
      return const ServiceUnavailableFailure(
          'Stock service is temporarily unavailable. Nothing was changed, please try again shortly.');
    case 'SERVICE_UNAVAILABLE':
      return const ServiceUnavailableFailure(
          'The service is temporarily unavailable. Please try again shortly.');
    case 'PAYLOAD_TOO_LARGE':
      return const ValidationFailure('The file is too large.', {});
  }

  // Unknown or missing code: fall back to the status.
  return switch (status) {
    401 => const UnauthenticatedFailure(
        'Your session has expired. Please sign in again.'),
    403 => const ForbiddenFailure('You are not allowed to do this.'),
    404 => const NotFoundFailure('Not found.'),
    429 => RateLimitedFailure('Too many attempts. Please wait and try again.',
        retryAfter: _seconds(retryAfterHeader)),
    503 => const ServiceUnavailableFailure(
        'The service is temporarily unavailable. Please try again shortly.'),
    _ => const ServerFailure('Something went wrong on our side. Please try again.'),
  };
}

Map<String, List<String>> _fieldErrors(Map<String, dynamic> details) => {
      for (final entry in details.entries)
        entry.key: [
          if (entry.value is List)
            for (final m in entry.value as List) m.toString()
          else
            entry.value.toString()
        ],
    };

List<StockProblem> _stockProblems(Map<String, dynamic> details) => [
      for (final raw in (details['items'] as List? ?? const []))
        if (raw is Map)
          StockProblem(
            productId: (raw['product_id'] as num?)?.toInt() ?? 0,
            name: (raw['name'] ?? '').toString(),
            requested: (raw['requested'] as num?)?.toInt() ?? 0,
            available: (raw['available'] as num?)?.toInt() ?? 0,
          ),
    ];

Duration? _seconds(String? header) {
  final s = int.tryParse(header ?? '');
  return s == null ? null : Duration(seconds: s);
}
