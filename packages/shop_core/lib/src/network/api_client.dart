import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../errors/app_failure.dart';
import '../errors/failure_mapper.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Thin wrapper around Dio. Every call either returns data or throws an
/// [AppFailure]; callers never see DioException.
class ApiClient {
  ApiClient({
    required this.config,
    required this.storage,
    void Function()? onSessionExpired,
    HttpClientAdapter? adapter,
  }) : dio = Dio(BaseOptions(
          baseUrl: config.apiUrl,
          // A down backend must never hang the UI.
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        )) {
    final refreshDio = Dio(dio.options.copyWith());
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
      refreshDio.httpClientAdapter = adapter;
    }
    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      storage: storage,
      onSessionExpired: onSessionExpired,
    ));
  }

  final ApiConfig config;
  final TokenStorage storage;
  final Dio dio;

  /// Sends the request without the bearer token (login, register).
  static Options noAuth() => Options(extra: {AuthInterceptor.noAuthKey: true});

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, dynamic>? query}) =>
      _run(() => dio.get<Map<String, dynamic>>(path, queryParameters: query));

  Future<Map<String, dynamic>> postJson(String path,
      {Object? body, Options? options}) =>
      _run(() => dio.post<Map<String, dynamic>>(path, data: body, options: options));

  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) =>
      _run(() => dio.patch<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> postMultipart(String path, FormData form) =>
      _run(() => dio.post<Map<String, dynamic>>(path, data: form));

  /// For endpoints that answer 204 with no body.
  Future<void> postEmpty(String path) =>
      _run(() => dio.post<dynamic>(path)).then((_) {});

  Future<Map<String, dynamic>> _run(
      Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

/// Convenience for tests and callers that need to know a failure type.
extension AppFailureX on Object {
  bool get isUnauthenticated => this is UnauthenticatedFailure;
}
