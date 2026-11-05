import 'package:shop_core/shop_core.dart';
import 'package:web/web.dart' as web;

/// Keeps the JWT in the browser's sessionStorage: it is gone when the tab is
/// closed and is never shared with other tabs (safer than localStorage for an
/// admin console). Falls back to memory if the browser blocks storage.
class SessionTokenStorage implements TokenStorage {
  static const _key = 'admin_access_token';
  String? _memory;

  @override
  Future<String?> read() async {
    try {
      return web.window.sessionStorage.getItem(_key) ?? _memory;
    } catch (_) {
      return _memory;
    }
  }

  @override
  Future<void> write(String token) async {
    _memory = token;
    try {
      web.window.sessionStorage.setItem(_key, token);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    _memory = null;
    try {
      web.window.sessionStorage.removeItem(_key);
    } catch (_) {}
  }
}
