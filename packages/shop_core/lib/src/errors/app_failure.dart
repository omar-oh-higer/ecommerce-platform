import 'package:equatable/equatable.dart';

/// Every error the UI can see. Built once, in the network layer, from the
/// backend error envelope `{"error":{"code","message","details"}}`.
sealed class AppFailure extends Equatable implements Exception {
  const AppFailure(this.message);

  /// Text that is safe to show to the user.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, this.fieldErrors);

  /// Field name -> messages, e.g. `{'email': ['The email has already been taken.']}`.
  final Map<String, List<String>> fieldErrors;

  String? firstErrorFor(String field) {
    final list = fieldErrors[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  @override
  List<Object?> get props => [message, fieldErrors];
}

class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure(super.message);
}

/// Missing, invalid or expired token (401).
class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure(super.message);
}

class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure(super.message);
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

class StockProblem extends Equatable {
  const StockProblem({
    required this.productId,
    required this.name,
    required this.requested,
    required this.available,
  });

  final int productId;
  final String name;
  final int requested;
  final int available;

  @override
  List<Object?> get props => [productId, name, requested, available];
}

class InsufficientStockFailure extends AppFailure {
  const InsufficientStockFailure(super.message, this.items);
  final List<StockProblem> items;

  @override
  List<Object?> get props => [message, items];
}

class InvalidTransitionFailure extends AppFailure {
  const InvalidTransitionFailure(super.message, {this.current, this.allowed = const []});
  final String? current;
  final List<String> allowed;

  @override
  List<Object?> get props => [message, current, allowed];
}

class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure(super.message, {this.retryAfter});

  /// From the `Retry-After` header, when the server sent it.
  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, retryAfter];
}

/// 503: inventory service (or the API) is down or too slow. Nothing was saved.
class ServiceUnavailableFailure extends AppFailure {
  const ServiceUnavailableFailure(super.message);
}

/// No connection, DNS error or timeout.
class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message);
}
