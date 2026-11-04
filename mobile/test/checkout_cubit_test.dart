import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shop_core/shop_core.dart';
import 'package:shop_mobile/features/cart/cart_cubit.dart';
import 'package:shop_mobile/features/orders/checkout_cubit.dart';

class MockOrders extends Mock implements OrdersRepository {}

class MemStorage implements CartStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String json) async {}
}

Product product(int id, {int qty = 10}) => Product(
      id: id,
      name: 'P$id',
      description: '',
      price: Money.parse('10.00'),
      stock: Stock(status: StockStatus.inStock, quantity: qty),
    );

const order = Order(id: 9, status: OrderStatus.pending, total: Money(2000), itemsCount: 1);

void main() {
  late MockOrders orders;
  late CartCubit cart;

  setUpAll(() => registerFallbackValue(<OrderLine>[]));

  setUp(() {
    orders = MockOrders();
    cart = CartCubit(MemStorage())..add(product(1), quantity: 2);
  });

  blocTest<CheckoutCubit, CheckoutState>(
    'success sends only id+quantity, then empties the cart',
    build: () {
      when(() => orders.place(any())).thenAnswer((_) async => order);
      return CheckoutCubit(orders, cart);
    },
    act: (c) => c.submit(),
    expect: () => [const CheckoutSubmitting(), const CheckoutSuccess(order)],
    verify: (_) {
      expect(verify(() => orders.place(captureAny())).captured.single,
          [const OrderLine(1, 2)]);
      expect(cart.state.isEmpty, isTrue);
    },
  );

  blocTest<CheckoutCubit, CheckoutState>(
    '409 keeps the cart, then "update cart" shrinks it to what is available',
    build: () {
      when(() => orders.place(any())).thenThrow(const InsufficientStockFailure('x', [
        StockProblem(productId: 1, name: 'P1', requested: 2, available: 1),
      ]));
      return CheckoutCubit(orders, cart);
    },
    act: (c) async {
      await c.submit();
      expect(cart.state.items.single.quantity, 2);
      c.adjustCartToStock();
    },
    expect: () => [
      const CheckoutSubmitting(),
      isA<CheckoutFailed>(),
      const CheckoutIdle(),
    ],
    verify: (_) => expect(cart.state.items.single.quantity, 1),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    '503 and 429 keep the cart so the user can retry',
    build: () {
      var n = 0;
      when(() => orders.place(any())).thenAnswer((_) async {
        n++;
        throw n == 1
            ? const ServiceUnavailableFailure('down')
            : const RateLimitedFailure('slow', retryAfter: Duration(seconds: 30));
      });
      return CheckoutCubit(orders, cart);
    },
    act: (c) async {
      await c.submit();
      await c.submit();
    },
    expect: () => [
      const CheckoutSubmitting(),
      const CheckoutFailed(ServiceUnavailableFailure('down')),
      const CheckoutSubmitting(),
      const CheckoutFailed(RateLimitedFailure('slow', retryAfter: Duration(seconds: 30))),
    ],
    verify: (_) => expect(cart.state.items.length, 1),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a second tap while submitting does not send a second order',
    build: () {
      when(() => orders.place(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return order;
      });
      return CheckoutCubit(orders, cart);
    },
    act: (c) async {
      final first = c.submit();
      await c.submit(); // ignored
      await first;
    },
    verify: (_) => verify(() => orders.place(any())).called(1),
  );
}
