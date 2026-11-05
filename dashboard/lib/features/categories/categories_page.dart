import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

import '../../core/widgets.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _name = TextEditingController();
  List<Category>? _categories;
  AppFailure? _loadFailure;
  AppFailure? _failure;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadFailure = null);
    try {
      final c = await context.read<CatalogRepository>().categories();
      if (mounted) setState(() => _categories = c);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _loadFailure = f);
    }
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _failure = const ValidationFailure('Enter a category name.', {}));
      return;
    }
    if (name.length > 100) {
      setState(() => _failure = const ValidationFailure('At most 100 characters.', {}));
      return;
    }
    final repo = context.read<CatalogRepository>();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await repo.createCategory(name);
      _name.clear();
      await _load();
      if (mounted) showSnack(context, 'Category "$name" added');
    } on ValidationFailure catch (f) {
      // e.g. the name already exists
      if (mounted) setState(() => _failure = ValidationFailure(f.firstErrorFor('name') ?? f.message, f.fieldErrors));
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _categories;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Categories', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        SizedBox(
          width: 480,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'New category', border: OutlineInputBorder()),
                onSubmitted: (_) => _saving ? null : _add(),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton(onPressed: _saving ? null : _add, child: const Text('Add')),
            ),
          ]),
        ),
        if (_failure != null) Padding(padding: const EdgeInsets.only(top: 12), child: SizedBox(width: 480, child: FailureBox(_failure!))),
        const SizedBox(height: 16),
        Expanded(
          child: switch ((list, _loadFailure)) {
            (null, null) => const Center(child: CircularProgressIndicator()),
            (null, final f?) => ErrorView(f, onRetry: _load),
            (final l?, _) => SizedBox(
                width: 480,
                child: Card(
                  child: ListView(children: [
                    for (final c in l)
                      ListTile(title: Text(c.name), subtitle: Text(c.slug), trailing: Text('${c.productsCount ?? 0} products')),
                  ]),
                ),
              ),
          },
        ),
      ]),
    );
  }
}
