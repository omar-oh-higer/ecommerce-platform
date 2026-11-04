/// Where the backend lives. Set with `--dart-define=API_BASE_URL=http://host:8000`.
class ApiConfig {
  const ApiConfig({required this.baseUrl});

  /// Server root without the `/api/v1` suffix, e.g. `http://localhost:8000`.
  final String baseUrl;

  static const String _fromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  factory ApiConfig.fromEnvironment() => const ApiConfig(baseUrl: _fromEnv);

  String get apiUrl => '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1';

  /// Image URLs are built by the backend from its own APP_URL (localhost),
  /// which is unreachable from an Android emulator. Point them at [baseUrl].
  String? resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final image = Uri.tryParse(url);
    final base = Uri.tryParse(baseUrl);
    if (image == null || base == null) return url;
    if (image.host != 'localhost' && image.host != '127.0.0.1') return url;
    return image
        .replace(scheme: base.scheme, host: base.host, port: base.port)
        .toString();
  }
}
