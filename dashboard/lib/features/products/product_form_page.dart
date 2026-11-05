import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../../core/widgets.dart';
import 'product_form.dart';
import 'products_cubit.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key});
  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController(text: '0');

  List<Category> _categories = const [];
  Category? _category;
  PickedImage? _image;
  String? _imageError;
  AppFailure? _loadFailure;
  AppFailure? _failure; // from the server when saving
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadFailure = null);
    try {
      final c = await context.read<CatalogRepository>().categories();
      if (mounted) setState(() => _categories = c);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _loadFailure = f);
    }
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ProductRules.allowedExtensions);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final error = ProductRules.image(file.name, bytes.length);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _image = null;
        _imageError = error;
      });
      return;
    }
    setState(() {
      _image = PickedImage(file.name, bytes);
      _imageError = null;
    });
  }

  Future<void> _save() async {
    final formOk = _form.currentState!.validate();
    setState(() => _imageError = _image == null ? 'Choose an image' : null);
    if (!formOk || _image == null || _category == null) return;
    final repo = context.read<CatalogRepository>();
    final list = context.read<ProductsCubit>();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final p = await repo.createProduct(
        categoryId: _category!.id,
        name: _name.text,
        description: _description.text,
        price: _price.text.trim(),
        quantity: int.parse(_quantity.text.trim()),
        imageBytes: _image!.bytes,
        imageFilename: _image!.name,
      );
      if (!mounted) return;
      showSnack(context, '${p.name} was added');
      list.load();
      context.go('/products');
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _failure is ValidationFailure ? _failure as ValidationFailure : null;
    InputDecoration deco(String label, String field) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder(), errorText: fields?.firstErrorFor(field));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(children: [
        Row(children: [
          IconButton(onPressed: () => context.go('/products'), icon: const Icon(Icons.arrow_back)),
          Text('Add product', style: Theme.of(context).textTheme.headlineSmall),
        ]),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_loadFailure != null) ...[
                  ErrorView(_loadFailure!, onRetry: _loadCategories),
                  const SizedBox(height: 16),
                ],
                if (_failure != null && fields == null) ...[FailureBox(_failure!), const SizedBox(height: 16)],
                DropdownButtonFormField<Category>(
                  initialValue: _category,
                  decoration: deco('Category', 'category_id'),
                  items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c.name))],
                  onChanged: (c) => setState(() => _category = c),
                  validator: (v) => v == null ? 'Choose a category' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _name, decoration: deco('Name', 'name'), validator: ProductRules.name),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _description,
                    maxLines: 4,
                    decoration: deco('Description (optional)', 'description'),
                    validator: ProductRules.description),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: deco('Price', 'price'),
                      validator: ProductRules.price,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: deco('Initial stock', 'quantity'),
                      validator: ProductRules.quantity,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  OutlinedButton.icon(
                      onPressed: _saving ? null : _pickImage, icon: const Icon(Icons.image_outlined), label: const Text('Choose image')),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_image?.name ?? 'JPG, PNG or WebP, up to 2 MB', overflow: TextOverflow.ellipsis)),
                ]),
                if (_imageError != null || fields?.firstErrorFor('image') != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_imageError ?? fields!.firstErrorFor('image')!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                if (_image != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(height: 140, child: Image.memory(_image!.bytes, fit: BoxFit.contain)),
                  ),
                const SizedBox(height: 24),
                Row(children: [
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save product'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(onPressed: _saving ? null : () => context.go('/products'), child: const Text('Cancel')),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
