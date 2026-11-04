import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/shop_core.dart';
import 'package:shop_mobile/features/cart/cart_cubit.dart';

class MemoryCartStorage implements CartStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String json) async => value = json;
}

Product product(int id, {int? qty = 10, String price = '10.00', StockStatus status = StockStatus.inStock}) =>
    Product(
      id: id,
      name: 'P$id',
      description: '',
      price: Money.parse(price),
      stock: Stock(status: status, quantity: qty),
    );

void main() {
  late MemoryCartStorage storage;
  late CartCubit cart;

  setUp(() {
    storage = MemoryCartStorage();
    cart = CartCubit(storage);
  });

  test('add merges lines and totals use exact money', () {
    cart.add(product(1, price: '29.50'), quantity: 2);
    cart.add(product(1, price: '29.50'));
    expect(cart.state.items.single.quantity, 3);
    expect(cart.state.total.toString(), '\$88.50');
  });

  test('quantity is capped by known stock', () {
    cart.add(product(1, qty: 3), quantity: 10);
    expect(cart.state.items.single.quantity, 3);
    cart.setQuantity(1, 50);
    expect(cart.state.items.single.quantity, 3);
  });

  test('cannot add out-of-stock or unavailable products', () {
    expect(cart.add(product(1, qty: 0, status: StockStatus.outOfStock)), isFalse);
    expect(cart.add(product(2, qty: null, status: StockStatus.unavailable)), isFalse);
    expect(cart.state.isEmpty, isTrue);
  });

  test('cart holds at most 20 lines', () {
    for (var i = 1; i <= 20; i++) {
      expect(cart.add(product(i)), isTrue);
    }
    expect(cart.add(product(21)), isFalse);
    expect(cart.state.items.length, 20);
  });

  test('setting quantity to 0 removes the line', () {
    cart.add(product(1));
    cart.setQuantity(1, 0);
    expect(cart.state.isEmpty, isTrue);
  });

  test('cart is saved and restored', () async {
    cart.add(product(1, price: '12.00'), quantity: 2);
    final restored = CartCubit(storage);
    await restored.load();
    expect(restored.state.items.single.quantity, 2);
    expect(restored.state.total.cents, 2400);
  });

  test('409 availability shrinks or drops lines', () {
    cart.add(product(1), quantity: 5);
    cart.add(product(2), quantity: 2);
    cart.applyAvailability(const [
      StockProblem(productId: 1, name: 'P1', requested: 5, available: 2),
      StockProblem(productId: 2, name: 'P2', requested: 2, available: 0),
    ]);
    expect(cart.state.items.length, 1);
    expect(cart.state.items.single.quantity, 2);
  });
}
