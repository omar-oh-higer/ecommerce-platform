import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';

import 'app.dart';
import 'features/cart/cart_cubit.dart';
import 'features/catalog/products_cubit.dart';
import 'core/secure_token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // `--dart-define=API_BASE_URL=...` wins; otherwise pick the emulator default.
  final config = const bool.hasEnvironment('API_BASE_URL')
      ? ApiConfig.fromEnvironment()
      : ApiConfig(
          baseUrl: Platform.isAndroid
              ? 'http://10.0.2.2:8000'
              : 'http://localhost:8000');

  if (kReleaseMode && !config.isSecureOrLocal) {
    throw StateError('Release builds must use an https:// API_BASE_URL.');
  }

  final storage = SecureTokenStorage();
  late final AuthCubit auth;
  final api = ApiClient(
    config: config,
    storage: storage,
    onSessionExpired: () => auth.sessionExpired(),
  );
  auth = AuthCubit(AuthRepository(api: api, storage: storage))..start();

  final catalog = CatalogRepository(api);
  final notifications = NotificationsRepository(api);
  runApp(ShopApp(
    auth: auth,
    config: config,
    api: api,
    catalog: catalog,
    orders: OrdersRepository(api),
    notifications: notifications,
    unread: UnreadCountCubit(PollingNotificationSource(notifications)),
    cart: CartCubit(PrefsCartStorage()),
    products: ProductsCubit(catalog)..load(),
  ));
}
