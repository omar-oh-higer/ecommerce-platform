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

  /// True for https, or for plain http to this machine / a private network
  /// (development). A release build must refuse anything else: a JWT must not
  /// travel over plain http across the internet.
  bool get isSecureOrLocal {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme != 'http') return false;
    final h = uri.host;
    if (h == 'localhost' || h == '10.0.2.2' || h.endsWith('.local')) return true;
    final m = RegExp(r'^(\d+)\.(\d+)\.\d+\.\d+$').firstMatch(h);
    if (m == null) return false;
    final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
    return a == 127 || a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
  }

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
