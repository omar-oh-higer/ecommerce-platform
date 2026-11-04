import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/shop_core.dart';

void main() {
  orderTests();
  test('Money parses API strings without floating point', () {
    expect(Money.parse('12.00').cents, 1200);
    expect(Money.parse('79.99').cents, 7999);
    expect(Money.parse('5').cents, 500);
    expect(Money.parse('0.1').cents, 10);
    expect(Money.parse('garbage'), Money.zero);
    expect((Money.parse('29.50') * 3 + Money.parse('0.10')).toString(), '\$88.60');
  });

  test('Product.fromJson matches the real API shape', () {
    final p = Product.fromJson({
      'id': 3,
      'name': 'Smart Watch',
      'description': 'x',
      'price': '149.00',
      'image_url': null,
      'category': {'id': 1, 'name': 'Electronics', 'slug': 'electronics'},
      'stock': {'quantity': 1, 'status': 'in_stock'},
      'created_at': '2026-11-04T23:02:28+00:00',
    });
    expect(p.price.cents, 14900);
    expect(p.imageUrl, isNull);
    expect(p.canBuy, isTrue);
    expect(p.stock.quantity, 1);
  });

  test('unavailable stock has no quantity', () {
    final p = Product.fromJson({
      'id': 1, 'name': 'a', 'price': '1.00',
      'stock': {'quantity': null, 'status': 'unavailable'},
    });
    expect(p.stock.status, StockStatus.unavailable);
    expect(p.canBuy, isFalse);
  });

  test('Paged reads meta', () {
    final page = Paged.fromJson({
      'data': [{'id': 1, 'name': 'C', 'slug': 'c'}],
      'meta': {'current_page': 1, 'last_page': 3, 'total': 7},
    }, Category.fromJson);
    expect(page.hasMore, isTrue);
    expect(page.total, 7);
  });
}

void orderTests() {
  test('Order list item uses items_count, detail uses items', () {
    final list = Order.fromJson({
      'id': 1, 'status': 'pending', 'total': '53.50', 'items_count': 2,
      'created_at': '2026-11-04T20:24:14+00:00',
    });
    expect(list.itemsCount, 2);
    expect(list.items, isEmpty);
    expect(list.nextStatuses, isEmpty);

    final detail = Order.fromJson({
      'id': 1, 'status': 'confirmed', 'total': '53.50',
      'items': [
        {'product_id': 6, 'name': 'T', 'unit_price': '12.00', 'quantity': 2, 'line_total': '24.00'}
      ],
      'customer': {'id': 2, 'name': 'C', 'email': 'c@x.y'},
      'next_statuses': ['shipped', 'cancelled'],
    });
    expect(detail.itemsCount, 1);
    expect(detail.items.single.lineTotal.cents, 2400);
    expect(detail.nextStatuses, [OrderStatus.shipped, OrderStatus.cancelled]);
    expect(detail.customer?.email, 'c@x.y');
  });
}
