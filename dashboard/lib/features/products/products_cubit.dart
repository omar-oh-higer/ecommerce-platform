import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

class ProductsState extends Equatable {
  const ProductsState({
    this.products = const [],
    this.page = 1,
    this.lastPage = 1,
    this.total = 0,
    this.search = '',
    this.loading = false,
    this.failure,
  });

  final List<Product> products;
  final int page;
  final int lastPage;
  final int total;
  final String search;
  final bool loading;
  final AppFailure? failure;

  @override
  List<Object?> get props => [products, page, lastPage, total, search, loading, failure];
}

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit(this._repo) : super(const ProductsState());

  final CatalogRepository _repo;
  int _generation = 0;

  Future<void> load({int page = 1, String? search}) async {
    final q = search ?? state.search;
    final gen = ++_generation;
    emit(ProductsState(
        products: state.products, page: page, lastPage: state.lastPage, total: state.total, search: q, loading: true));
    try {
      final r = await _repo.products(page: page, perPage: 15, search: q);
      if (gen != _generation) return;
      emit(ProductsState(products: r.items, page: r.page, lastPage: r.lastPage, total: r.total, search: q));
    } on AppFailure catch (f) {
      if (gen != _generation) return;
      emit(ProductsState(
          products: state.products, page: page, lastPage: state.lastPage, total: state.total, search: q, failure: f));
    }
  }

  Future<void> refresh() => load(page: state.page);

  /// Replace one row after its stock changed.
  void replace(Product p) => emit(ProductsState(
      products: [for (final x in state.products) x.id == p.id ? p : x],
      page: state.page, lastPage: state.lastPage, total: state.total, search: state.search));
}
