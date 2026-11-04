import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';

import 'app.dart';
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

  final storage = SecureTokenStorage();
  late final AuthCubit auth;
  final api = ApiClient(
    config: config,
    storage: storage,
    onSessionExpired: () => auth.sessionExpired(),
  );
  auth = AuthCubit(AuthRepository(api: api, storage: storage))..start();

  runApp(ShopApp(auth: auth, config: config, api: api));
}
