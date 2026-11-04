import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/cart/cart_cubit.dart';
import 'features/cart/cart_page.dart';
import 'features/orders/checkout_cubit.dart';
import 'features/orders/checkout_page.dart';
import 'features/orders/order_detail_page.dart';
import 'features/orders/orders_cubit.dart';
import 'features/orders/orders_page.dart';
import 'features/catalog/product_detail_page.dart';
import 'features/catalog/products_cubit.dart';
import 'features/catalog/products_page.dart';

class ShopApp extends StatefulWidget {
  const ShopApp({
    super.key,
    required this.auth,
    required this.config,
    required this.api,
    required this.catalog,
    required this.orders,
    required this.cart,
    required this.products,
  });

  final CatalogRepository catalog;
  final OrdersRepository orders;
  final CartCubit cart;
  final ProductsCubit products;
  final AuthCubit auth;
  final ApiConfig config;
  final ApiClient api;

  @override
  State<ShopApp> createState() => _ShopAppState();
}

class _ShopAppState extends State<ShopApp> {
  late final GoRouter _router = _buildRouter(widget.auth);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.api),
        RepositoryProvider.value(value: widget.config),
        RepositoryProvider.value(value: widget.catalog),
        RepositoryProvider.value(value: widget.orders),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: widget.auth),
          BlocProvider.value(value: widget.cart),
          BlocProvider.value(value: widget.products),
        ],
        child: MaterialApp.router(
          title: 'Shop',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF1B2433),
            useMaterial3: true,
          ),
          routerConfig: _router,
        ),
      ),
    );
  }
}

/// Route guard: the server is the real authority, this only decides which
/// screen to show for the current session state.
GoRouter _buildRouter(AuthCubit auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _StreamListenable(auth.stream),
    redirect: (context, state) {
      final s = auth.state;
      final loc = state.matchedLocation;
      final inAuthArea = loc == '/login' || loc == '/register';
      if (s is AuthUnknown) return loc == '/splash' ? null : '/splash';
      if (s is Authenticated) return (inAuthArea || loc == '/splash') ? '/' : null;
      return inAuthArea ? null : '/login';
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/', builder: (_, _) => const ProductsPage()),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) =>
            ProductDetailPage(productId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/cart', builder: (_, _) => const CartPage()),
      GoRoute(
        path: '/checkout',
        builder: (context, _) => BlocProvider(
          create: (_) => CheckoutCubit(context.read<OrdersRepository>(), context.read<CartCubit>()),
          child: const CheckoutPage(),
        ),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, _) => BlocProvider(
          create: (_) => OrdersCubit(context.read<OrdersRepository>())..load(),
          child: const OrdersPage(),
        ),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => OrderDetailPage(orderId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
