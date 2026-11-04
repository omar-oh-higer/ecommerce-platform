import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/shop_core.dart';

Map<String, dynamic> err(String code, {Map<String, dynamic> details = const {}}) =>
    {'error': {'code': code, 'message': 'x', 'details': details}};

void main() {
  test('422 keeps field errors', () {
    final f = mapErrorResponse(422, err('VALIDATION_FAILED', details: {
      'email': ['Taken.'],
    })) as ValidationFailure;
    expect(f.firstErrorFor('email'), 'Taken.');
    expect(f.firstErrorFor('name'), isNull);
  });

  test('401 codes', () {
    expect(mapErrorResponse(401, err('INVALID_CREDENTIALS')),
        isA<InvalidCredentialsFailure>());
    expect(mapErrorResponse(401, err('INVALID_TOKEN')), isA<UnauthenticatedFailure>());
  });

  test('409 insufficient stock lists items', () {
    final f = mapErrorResponse(409, err('INSUFFICIENT_STOCK', details: {
      'items': [
        {'product_id': 3, 'name': 'Watch', 'requested': 2, 'available': 1}
      ]
    })) as InsufficientStockFailure;
    expect(f.items.single.available, 1);
    expect(f.items.single.name, 'Watch');
  });

  test('429 reads Retry-After', () {
    final f = mapErrorResponse(429, err('TOO_MANY_REQUESTS'),
        retryAfterHeader: '42') as RateLimitedFailure;
    expect(f.retryAfter, const Duration(seconds: 42));
  });

  test('503 and unknown bodies', () {
    expect(mapErrorResponse(503, err('INVENTORY_UNAVAILABLE')),
        isA<ServiceUnavailableFailure>());
    expect(mapErrorResponse(500, '<html>'), isA<ServerFailure>());
    expect(mapErrorResponse(403, null), isA<ForbiddenFailure>());
  });

  test('image host is rewritten for emulators', () {
    const c = ApiConfig(baseUrl: 'http://10.0.2.2:8000');
    expect(c.resolveImageUrl('http://localhost:8000/storage/products/a.png'),
        'http://10.0.2.2:8000/storage/products/a.png');
    expect(c.resolveImageUrl('https://cdn.example.com/a.png'),
        'https://cdn.example.com/a.png');
    expect(c.resolveImageUrl(null), isNull);
    expect(c.apiUrl, 'http://10.0.2.2:8000/api/v1');
  });
}
