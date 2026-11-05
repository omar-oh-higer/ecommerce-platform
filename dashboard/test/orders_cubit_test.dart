import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shop_core/shop_core.dart';
import 'package:shop_dashboard/features/orders/orders_cubit.dart';

class MockOrders extends Mock implements OrdersRepository {}

Order order(int id, OrderStatus s) => Order(id: id, status: s, total: const Money(1000), itemsCount: 1);

void main() {
  late MockOrders repo;
  setUp(() {
    repo = MockOrders();
    when(() => repo.list(page: any(named: 'page'), perPage: any(named: 'perPage'), status: any(named: 'status')))
        .thenAnswer((i) async {
      final per = i.namedArguments[#perPage] as int;
      return per == 1
          ? const Paged<Order>(items: [], page: 1, lastPage: 3, total: 3)
          : Paged(items: [order(2, OrderStatus.pending), order(1, OrderStatus.pending)], page: 1, lastPage: 1, total: 2);
    });
  });

  test('loads the table and real per-status totals', () async {
    final c = OrdersCubit(repo);
    await c.load();
    await Future<void>.delayed(Duration.zero);
    expect(c.state.orders.length, 2);
    expect(c.state.countsByStatus.length, OrderStatus.values.length);
    expect(c.state.countsByStatus[OrderStatus.shipped], 3);
  });

  test('filter and page are sent to the server', () async {
    final c = OrdersCubit(repo);
    await c.load(status: OrderStatus.cancelled, page: 2);
    verify(() => repo.list(page: 2, perPage: 15, status: OrderStatus.cancelled)).called(1);
  });

  test('a failure keeps the old rows and reports the error', () async {
    final c = OrdersCubit(repo);
    await c.load();
    when(() => repo.list(page: any(named: 'page'), perPage: 15, status: any(named: 'status')))
        .thenThrow(const NetworkFailure('offline'));
    await c.load(page: 2);
    expect(c.state.failure, isA<NetworkFailure>());
    expect(c.state.orders, isNotEmpty);
  });
}
