import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/shop_core.dart';

/// Fake server: protected `/orders` accepts only [validToken]; `/auth/refresh`
/// swaps the old token for a new one and blacklists the old (like the backend).
class FakeServer implements HttpClientAdapter {
  String validToken = 'new';
  int refreshCalls = 0;
  bool refreshFails = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
      Future<void>? c) async {
    ResponseBody json(int code, Object body) => ResponseBody.fromString(
        jsonEncode(body), code,
        headers: {Headers.contentTypeHeader: ['application/json']});
    final auth = o.headers['Authorization'];
    if (o.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshFails || auth == null) {
        return json(401, {'error': {'code': 'INVALID_TOKEN', 'message': '', 'details': {}}});
      }
      return json(200, {'access_token': validToken});
    }
    if (auth == 'Bearer $validToken') return json(200, {'ok': true});
    return json(401, {'error': {'code': 'INVALID_TOKEN', 'message': '', 'details': {}}});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeServer server;
  late InMemoryTokenStorage storage;
  late int expired;
  late ApiClient api;

  setUp(() async {
    server = FakeServer();
    storage = InMemoryTokenStorage();
    await storage.write('old');
    expired = 0;
    api = ApiClient(
      config: const ApiConfig(baseUrl: 'http://x'),
      storage: storage,
      adapter: server,
      onSessionExpired: () => expired++,
    );
  });

  test('concurrent 401s trigger exactly one refresh and all succeed', () async {
    final results = await Future.wait([
      api.getJson('/orders'),
      api.getJson('/orders'),
      api.getJson('/orders'),
    ]);
    expect(results.every((r) => r['ok'] == true), isTrue);
    expect(server.refreshCalls, 1);
    expect(await storage.read(), 'new');
    expect(expired, 0);
  });

  test('failed refresh clears the session and reports expiry', () async {
    server.refreshFails = true;
    await expectLater(api.getJson('/orders'), throwsA(isA<UnauthenticatedFailure>()));
    expect(await storage.read(), isNull);
    expect(expired, 1);
  });

  test('login 401 is not retried or treated as expiry', () async {
    final repo = AuthRepository(api: api, storage: storage);
    await expectLater(repo.login(email: 'a@b.c', password: 'x'),
        throwsA(isA<UnauthenticatedFailure>()));
    expect(server.refreshCalls, 0);
    expect(expired, 0);
  });
}
