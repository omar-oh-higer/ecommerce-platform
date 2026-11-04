import '../models/order.dart';
import '../models/paged.dart';
import '../network/api_client.dart';

class OrdersRepository {
  OrdersRepository(this.api);
  final ApiClient api;

  /// Throws [InsufficientStockFailure], [ServiceUnavailableFailure],
  /// [RateLimitedFailure] or [ValidationFailure] when the order is refused;
  /// in every one of those cases nothing was created.
  Future<Order> place(List<OrderLine> lines) async {
    final json = await api.postJson('/orders', body: {
      'items': [for (final l in lines) l.toJson()],
    });
    return Order.fromJson((json['data'] as Map).cast<String, dynamic>());
  }

  Future<Paged<Order>> list({int page = 1, int perPage = 15, OrderStatus? status}) async {
    final json = await api.getJson('/orders', query: {
      'page': page,
      'per_page': perPage,
      'status': ?status?.apiValue,
    });
    return Paged.fromJson(json, Order.fromJson);
  }

  Future<Order> get(int id) async {
    final json = await api.getJson('/orders/$id');
    return Order.fromJson((json['data'] as Map).cast<String, dynamic>());
  }

  /// Admin only. Throws [InvalidTransitionFailure] on a forbidden move.
  Future<Order> updateStatus(int id, OrderStatus status) async {
    final json = await api.patchJson('/orders/$id/status', body: {'status': status.apiValue});
    return Order.fromJson((json['data'] as Map).cast<String, dynamic>());
  }
}
