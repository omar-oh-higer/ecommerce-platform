import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import 'features/auth/login_page.dart';
import 'features/categories/categories_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/orders/order_detail_page.dart';
import 'features/orders/orders_cubit.dart';
import 'features/orders/orders_page.dart';
import 'features/products/product_form_page.dart';
import 'features/products/products_cubit.dart';
import 'features/products/products_page.dart';
import 'features/shell/admin_shell.dart';

class DashboardApp extends StatefulWidget {
  const DashboardApp({
    super.key,
    required this.auth,
    required this.config,
    required this.catalog,
    required this.orders,
    required this.notifications,
    required this.unread,
  });

  final AuthCubit auth;
  final ApiConfig config;
  final CatalogRepository catalog;
  final OrdersRepository orders;
  final NotificationsRepository notifications;
  final UnreadCountCubit unread;

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> with WidgetsBindingObserver {
  late final GoRouter _router = _buildRouter(widget.auth);
  late final StreamSubscription<AuthState> _sub;
  // Lists live as long as the signed-in session.
  late OrdersCubit _orders = OrdersCubit(widget.orders);
  late ProductsCubit _products = ProductsCubit(widget.catalog);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = widget.auth.stream.listen(_onAuth);
    _onAuth(widget.auth.state);
  }

  void _onAuth(AuthState s) {
    if (s is Authenticated) {
      widget.unread.start();
      _orders.load();
      _products.load();
    } else if (s is Unauthenticated) {
      // Drop the previous admin's data.
      widget.unread.reset();
      _orders.close();
      _products.close();
      setState(() {
        _orders = OrdersCubit(widget.orders);
        _products = ProductsCubit(widget.catalog);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.auth.state is! Authenticated) return;
    if (state == AppLifecycleState.resumed) {
      widget.unread.start();
    } else if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      widget.unread.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: widget.config),
          RepositoryProvider.value(value: widget.catalog),
          RepositoryProvider.value(value: widget.orders),
          RepositoryProvider.value(value: widget.notifications),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: widget.auth),
            BlocProvider.value(value: widget.unread),
            BlocProvider<OrdersCubit>.value(value: _orders),
            BlocProvider<ProductsCubit>.value(value: _products),
            BlocProvider(create: (c) => NotificationsCubit(c.read<NotificationsRepository>())),
          ],
          child: MaterialApp.router(
            title: 'Shop administration',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(colorSchemeSeed: const Color(0xFF1B2433), useMaterial3: true),
            routerConfig: _router,
          ),
        ),
      );
}

/// Only an administrator ever reaches the shell. (The server is the real
/// authority: a customer token gets 403 on every admin call anyway.)
GoRouter _buildRouter(AuthCubit auth) => GoRouter(
      initialLocation: '/orders',
      refreshListenable: _StreamListenable(auth.stream),
      redirect: (context, state) {
        final s = auth.state;
        final loc = state.matchedLocation;
        if (s is AuthUnknown) return loc == '/splash' ? null : '/splash';
        if (s is Authenticated) return (loc == '/login' || loc == '/splash') ? '/orders' : null;
        return loc == '/login' ? null : '/login';
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        ShellRoute(
          builder: (_, _, child) => AdminShell(child: child),
          routes: [
            GoRoute(path: '/orders', builder: (_, _) => const OrdersPage(), routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => OrderDetailPage(
                    key: ValueKey(state.pathParameters['id']), orderId: int.parse(state.pathParameters['id']!)),
              ),
            ]),
            GoRoute(path: '/products', builder: (_, _) => const ProductsPage(), routes: [
              GoRoute(path: 'new', builder: (_, _) => const ProductFormPage()),
            ]),
            GoRoute(path: '/categories', builder: (_, _) => const CategoriesPage()),
            GoRoute(path: '/notifications', builder: (_, _) => const NotificationsPage()),
          ],
        ),
      ],
    );

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
