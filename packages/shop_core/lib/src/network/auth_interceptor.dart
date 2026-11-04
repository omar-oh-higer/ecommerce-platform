import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Adds the bearer token and, on an expired token, refreshes it ONCE and
/// replays the request.
///
/// The backend blacklists the old token immediately (0s grace), so two
/// parallel refreshes would invalidate each other. All callers share a single
/// in-flight refresh.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.storage,
    required this.refreshDio,
    this.onSessionExpired,
  });

  final Dio dio;
  final Dio refreshDio; // no interceptors, so no loops
  final TokenStorage storage;
  final void Function()? onSessionExpired;

  Future<String?>? _refreshing;

  static const _retriedKey = 'auth_retried';
  static const noAuthKey = 'no_auth';

  bool _isAuthEndpoint(RequestOptions o) =>
      o.extra[noAuthKey] == true ||
      o.path.endsWith('/auth/login') ||
      o.path.endsWith('/auth/register') ||
      o.path.endsWith('/auth/refresh');

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['Accept'] = 'application/json';
    if (options.extra[noAuthKey] != true) {
      final token = await storage.read();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        _isAuthEndpoint(req) ||
        req.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final sent = (req.headers['Authorization'] as String?)?.substring(7);
    final current = await storage.read();
    if (current == null) return handler.next(err);

    // Another request already refreshed while this one was in flight.
    String? token = current != sent ? current : await _refresh(current);
    if (token == null) {
      await storage.clear();
      onSessionExpired?.call();
      return handler.next(err);
    }

    try {
      req.extra[_retriedKey] = true;
      req.headers['Authorization'] = 'Bearer $token';
      handler.resolve(await dio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String?> _refresh(String oldToken) {
    return _refreshing ??= _doRefresh(oldToken).whenComplete(() {
      _refreshing = null;
    });
  }

  Future<String?> _doRefresh(String oldToken) async {
    try {
      final res = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $oldToken'}),
      );
      final token = res.data?['access_token'] as String?;
      if (token != null) await storage.write(token);
      return token;
    } on DioException {
      return null;
    }
  }
}
