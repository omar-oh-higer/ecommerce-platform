import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../../core/widgets.dart';
import 'products_cubit.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _editStock(BuildContext context, Product p) async {
    final repo = context.read<CatalogRepository>();
    final cubit = context.read<ProductsCubit>();
    final updated = await showDialog<Product>(
      context: context,
      builder: (_) => _StockDialog(product: p, repo: repo),
    );
    if (updated != null) {
      cubit.replace(updated);
      if (context.mounted) showSnack(context, 'Stock of ${updated.name} is now ${updated.stock.quantity}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductsCubit>();
    final config = context.read<ApiConfig>();
    return BlocBuilder<ProductsCubit, ProductsState>(builder: (context, s) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Products', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            SizedBox(
              width: 260,
              child: SearchBar(
                hintText: 'Search products',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: (t) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () => cubit.load(search: t.trim()));
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => context.go('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(child: _body(context, s, cubit, config)),
        ]),
      );
    });
  }

  Widget _body(BuildContext context, ProductsState s, ProductsCubit cubit, ApiConfig config) {
    if (s.loading && s.products.isEmpty) return const Center(child: CircularProgressIndicator());
    if (s.failure != null && s.products.isEmpty) return ErrorView(s.failure!, onRetry: cubit.refresh);
    if (s.products.isEmpty) return const Center(child: Text('No products found.'));
    return Column(children: [
      if (s.failure != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: FailureBox(s.failure!)),
      Expanded(
        child: Card(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Price'), numeric: true),
                  DataColumn(label: Text('Stock'), numeric: true),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final p in s.products)
                    DataRow(cells: [
                      DataCell(SizedBox(
                        width: 40,
                        height: 40,
                        child: config.resolveImageUrl(p.imageUrl) == null
                            ? const Icon(Icons.image_outlined)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(config.resolveImageUrl(p.imageUrl)!, fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))),
                      )),
                      DataCell(Text(p.name)),
                      DataCell(Text(p.category?.name ?? '')),
                      DataCell(Text(p.price.toString())),
                      DataCell(_StockLabel(p.stock)),
                      DataCell(TextButton(onPressed: () => _editStock(context, p), child: const Text('Edit stock'))),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('Page ${s.page} of ${s.lastPage} · ${s.total} products'),
        IconButton(
            onPressed: s.page > 1 && !s.loading ? () => cubit.load(page: s.page - 1) : null,
            icon: const Icon(Icons.chevron_left)),
        IconButton(
            onPressed: s.page < s.lastPage && !s.loading ? () => cubit.load(page: s.page + 1) : null,
            icon: const Icon(Icons.chevron_right)),
      ]),
    ]);
  }
}

class _StockLabel extends StatelessWidget {
  const _StockLabel(this.stock);
  final Stock stock;
  @override
  Widget build(BuildContext context) => switch (stock.status) {
        StockStatus.inStock => Text('${stock.quantity}'),
        StockStatus.outOfStock => Text('0 (sold out)', style: TextStyle(color: Colors.red.shade700)),
        StockStatus.unavailable => Text('unavailable', style: TextStyle(color: Colors.orange.shade800)),
      };
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.product, required this.repo});
  final Product product;
  final CatalogRepository repo;
  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late final _qty = TextEditingController(text: '${widget.product.stock.quantity ?? ''}');
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final p = await widget.repo.updateStock(widget.product.id, int.parse(_qty.text));
      if (mounted) Navigator.pop(context, p);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Stock: ${widget.product.name}'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_failure != null) ...[FailureBox(_failure!), const SizedBox(height: 12)],
              TextFormField(
                controller: _qty,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New quantity', border: OutlineInputBorder()),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return 'Enter a whole number';
                  if (n < 0 || n > 1000000) return 'Between 0 and 1,000,000';
                  return null;
                },
                onFieldSubmitted: (_) => _saving ? null : _save(),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      );
}
