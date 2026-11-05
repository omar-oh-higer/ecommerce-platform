import 'package:flutter_test/flutter_test.dart';
import 'package:shop_dashboard/features/products/product_form.dart';

void main() {
  test('price follows the server rules and is never a double', () {
    for (final ok in ['0.01', '25', '25.5', '25.50', '99999999.99']) {
      expect(ProductRules.price(ok), isNull, reason: ok);
    }
    for (final bad in ['', '0', '0.00', '-1', '1.234', 'abc', '100000000', '1,5']) {
      expect(ProductRules.price(bad), isNotNull, reason: bad);
    }
  });

  test('quantity 0..1,000,000', () {
    expect(ProductRules.quantity('0'), isNull);
    expect(ProductRules.quantity('1000000'), isNull);
    expect(ProductRules.quantity('1000001'), isNotNull);
    expect(ProductRules.quantity('-1'), isNotNull);
    expect(ProductRules.quantity('1.5'), isNotNull);
    expect(ProductRules.quantity(''), isNotNull);
  });

  test('image type and size', () {
    expect(ProductRules.image('a.PNG', 1000), isNull);
    expect(ProductRules.image('a.webp', ProductRules.maxImageBytes), isNull);
    expect(ProductRules.image('a.jpeg', 1000), isNull);
    expect(ProductRules.image('a.svg', 1000), isNotNull, reason: 'SVG is rejected by the server');
    expect(ProductRules.image('a.gif', 1000), isNotNull);
    expect(ProductRules.image('a.png', ProductRules.maxImageBytes + 1), isNotNull);
    expect(ProductRules.image('a.png', 0), isNotNull);
    expect(ProductRules.image(null, null), isNotNull);
  });

  test('name and description limits', () {
    expect(ProductRules.name('  '), isNotNull);
    expect(ProductRules.name('x' * 256), isNotNull);
    expect(ProductRules.name('Mouse'), isNull);
    expect(ProductRules.description('x' * 5001), isNotNull);
  });
}
