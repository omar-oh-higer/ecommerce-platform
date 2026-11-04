import 'package:equatable/equatable.dart';

import 'money.dart';

enum OrderStatus {
  pending('pending', 'Pending review'),
  confirmed('confirmed', 'Confirmed'),
  shipped('shipped', 'Shipped'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled');

  const OrderStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  bool get isTerminal => this == delivered || this == cancelled;

  static OrderStatus parse(Object? v) => OrderStatus.values
      .firstWhere((s) => s.apiValue == v, orElse: () => OrderStatus.pending);
}

class OrderItem extends Equatable {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  final int productId;
  final String name;
  final Money unitPrice;
  final int quantity;
  final Money lineTotal;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        productId: (j['product_id'] as num).toInt(),
        name: j['name'] as String,
        unitPrice: Money.parse(j['unit_price']),
        quantity: (j['quantity'] as num).toInt(),
        lineTotal: Money.parse(j['line_total']),
      );

  @override
  List<Object?> get props => [productId, name, unitPrice, quantity, lineTotal];
}

class OrderCustomer extends Equatable {
  const OrderCustomer({required this.id, required this.name, required this.email});
  final int id;
  final String name;
  final String email;

  factory OrderCustomer.fromJson(Map<String, dynamic> j) => OrderCustomer(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        email: (j['email'] ?? '') as String,
      );

  @override
  List<Object?> get props => [id, name, email];
}

class Order extends Equatable {
  const Order({
    required this.id,
    required this.status,
    required this.total,
    required this.itemsCount,
    this.items = const [],
    this.customer,
    this.nextStatuses = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final OrderStatus status;
  final Money total;

  /// In lists the API sends `items_count`; in details it sends `items`.
  final int itemsCount;
  final List<OrderItem> items;

  /// Admin only.
  final OrderCustomer? customer;

  /// Admin only: the statuses this order may move to. Drive buttons from it.
  final List<OrderStatus> nextStatuses;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Order.fromJson(Map<String, dynamic> j) {
    final items = [
      for (final i in (j['items'] as List? ?? const []))
        OrderItem.fromJson((i as Map).cast<String, dynamic>())
    ];
    return Order(
      id: (j['id'] as num).toInt(),
      status: OrderStatus.parse(j['status']),
      total: Money.parse(j['total']),
      itemsCount: (j['items_count'] as num?)?.toInt() ?? items.length,
      items: items,
      customer: j['customer'] is Map
          ? OrderCustomer.fromJson((j['customer'] as Map).cast<String, dynamic>())
          : null,
      nextStatuses: [
        for (final s in (j['next_statuses'] as List? ?? const [])) OrderStatus.parse(s)
      ],
      createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((j['updated_at'] ?? '').toString()),
    );
  }

  @override
  List<Object?> get props =>
      [id, status, total, itemsCount, items, customer, nextStatuses, createdAt, updatedAt];
}

/// A line to send to `POST /orders`. Price is never sent: the server decides it.
class OrderLine extends Equatable {
  const OrderLine(this.productId, this.quantity);
  final int productId;
  final int quantity;

  Map<String, dynamic> toJson() => {'product_id': productId, 'quantity': quantity};

  @override
  List<Object?> get props => [productId, quantity];
}
