import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

class ProductsState extends Equatable {
  const ProductsState({
    this.products = const [],
    this.categories = const [],
    this.categoryId,
    this.search = '',
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
    this.failure,
  });

  final List<Product> products;
  final List<Category> categories;
  final int? categoryId;
  final String search;
  final int page;
  final bool hasMore;
  final bool loading;
  final AppFailure? failure;

  bool get initialLoading => loading && products.isEmpty;

  ProductsState copyWith({
    List<Product>? products,
    List<Category>? categories,
    Object? categoryId = _keep,
    String? search,
    int? page,
    bool? hasMore,
    bool? loading,
    Object? failure = _keep,
  }) => ProductsState(
    products: products ?? this.products,
    categories: categories ?? this.categories,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as int?,
    search: search ?? this.search,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    failure: identical(failure, _keep) ? this.failure : failure as AppFailure?,
  );

  static const _keep = Object();

  @override
  List<Object?> get props => [
    products,
    categories,
    categoryId,
    search,
    page,
    hasMore,
    loading,
    failure,
  ];
}

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit(this._repo) : super(const ProductsState());

  final CatalogRepository _repo;
  int _generation = 0; // ignores answers to outdated queries

  Future<void> load() async {
    _loadCategories();
    await refresh();
  }

  Future<void> refresh() => _fetch(reset: true);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _fetch(reset: false);
  }

  Future<void> selectCategory(int? id) {
    emit(state.copyWith(categoryId: id));
    return refresh();
  }

  Future<void> setSearch(String text) {
    if (text.trim() == state.search) return Future.value();
    emit(state.copyWith(search: text.trim()));
    return refresh();
  }

  Future<void> _loadCategories() async {
    try {
      emit(state.copyWith(categories: await _repo.categories()));
    } on AppFailure {
      // The chips are optional; the product list shows its own errors.
    }
  }

  Future<void> _fetch({required bool reset}) async {
    final gen = ++_generation;
    final page = reset ? 1 : state.page + 1;
    emit(
      state.copyWith(
        loading: true,
        failure: null,
        products: reset ? const [] : null,
        hasMore: reset ? true : null,
      ),
    );
    try {
      final result = await _repo.products(
        page: page,
        categoryId: state.categoryId,
        search: state.search,
      );
      if (gen != _generation) return;
      emit(
        state.copyWith(
          products: [...state.products, ...result.items],
          page: result.page,
          hasMore: result.hasMore,
          loading: false,
        ),
      );
    } on AppFailure catch (f) {
      if (gen != _generation) return;
      emit(state.copyWith(loading: false, failure: f));
    }
  }
}
