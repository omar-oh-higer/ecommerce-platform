import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

/// Side navigation shared by every admin screen.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  static const _items = [
    ('/orders', Icons.receipt_long_outlined, 'Orders'),
    ('/products', Icons.inventory_2_outlined, 'Products'),
    ('/categories', Icons.category_outlined, 'Categories'),
    ('/notifications', Icons.notifications_outlined, 'Notifications'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    var index = _items.indexWhere((e) => location.startsWith(e.$1));
    if (index < 0) index = 0;
    final user = context.select<AuthCubit, User?>((c) => c.state is Authenticated ? (c.state as Authenticated).user : null);

    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: index,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (i) => context.go(_items[i].$1),
          leading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Icon(Icons.storefront_outlined, size: 32),
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Tooltip(message: user?.email ?? '', child: const Icon(Icons.account_circle_outlined)),
                  const SizedBox(height: 8),
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout),
                    onPressed: () => context.read<AuthCubit>().logout(),
                  ),
                ]),
              ),
            ),
          ),
          destinations: [
            for (final e in _items)
              NavigationRailDestination(
                icon: e.$1 == '/notifications'
                    ? BlocBuilder<UnreadCountCubit, int>(
                        builder: (_, n) => Badge(isLabelVisible: n > 0, label: Text('$n'), child: Icon(e.$2)))
                    : Icon(e.$2),
                label: Text(e.$3),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ]),
    );
  }
}
