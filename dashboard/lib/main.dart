import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';

import 'app.dart';
import 'core/session_token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // `--dart-define=API_BASE_URL=http://host:8000` overrides the default.
  final config = ApiConfig.fromEnvironment();
  if (kReleaseMode && !config.isSecureOrLocal) {
    throw StateError('Release builds must use an https:// API_BASE_URL.');
  }

  final storage = SessionTokenStorage();
  late final AuthCubit auth;
  final api = ApiClient(config: config, storage: storage, onSessionExpired: () => auth.sessionExpired());
  // Only administrators may use this app.
  auth = AuthCubit(AuthRepository(api: api, storage: storage))
    ..adminOnly = true
    ..start();

  final notifications = NotificationsRepository(api);
  runApp(DashboardApp(
    auth: auth,
    config: config,
    catalog: CatalogRepository(api),
    orders: OrdersRepository(api),
    notifications: notifications,
    unread: UnreadCountCubit(PollingNotificationSource(notifications)),
  ));
}
