import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../cart/cart_cubit.dart';
import 'product_widgets.dart';
import 'products_cubit.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) context.read<ProductsCubit>().loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400),
        () => context.read<ProductsCubit>().setSearch(text));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductsCubit>();
    final user = context.select<AuthCubit, User?>(
        (c) => c.state is Authenticated ? (c.state as Authenticated).user : null);
    final cartCount = context.select<CartCubit, int>((c) => c.state.totalQuantity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => context.push('/cart'),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: BlocBuilder<UnreadCountCubit, int>(
              builder: (context, count) => Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            onPressed: () => context.push('/notifications').then((_) {
              if (context.mounted) context.read<UnreadCountCubit>().refresh();
            }),
          ),
          IconButton(
            tooltip: 'My orders',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/orders'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) {
              if (v == 'logout') context.read<AuthCubit>().logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(user?.email ?? '')),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SearchBar(
            hintText: 'Search products',
            leading: const Icon(Icons.search),
            onChanged: _onSearch,
            elevation: const WidgetStatePropertyAll(0),
          ),
        ),
        BlocBuilder<ProductsCubit, ProductsState>(
          buildWhen: (a, b) => a.categories != b.categories || a.categoryId != b.categoryId,
          builder: (context, s) => SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('All', s.categoryId == null, () => cubit.selectCategory(null)),
                for (final c in s.categories)
                  _chip(c.name, s.categoryId == c.id, () => cubit.selectCategory(c.id)),
              ],
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<ProductsCubit, ProductsState>(
            builder: (context, s) {
              if (s.initialLoading) return const Center(child: CircularProgressIndicator());
              if (s.failure != null && s.products.isEmpty) {
                return ErrorView(s.failure!, onRetry: cubit.refresh);
              }
              if (s.products.isEmpty) {
                return const Center(child: Text('No products found.'));
              }
              return RefreshIndicator(
                onRefresh: cubit.refresh,
                child: GridView.builder(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: s.products.length + (s.hasMore || s.failure != null ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == s.products.length) {
                      return s.failure != null
                          ? Center(
                              child: TextButton(
                                  onPressed: cubit.loadMore, child: const Text('Retry')))
                          : const Center(child: CircularProgressIndicator());
                    }
                    return _ProductCard(s.products[i]);
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(this.product);
  final Product product;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/products/${product.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: SizedBox.expand(child: ProductImage(product.imageUrl))),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(product.price.toString(),
                    style: Theme.of(context).textTheme.titleMedium),
                StockBadge(product.stock),
              ]),
            ),
          ]),
        ),
      );
}
