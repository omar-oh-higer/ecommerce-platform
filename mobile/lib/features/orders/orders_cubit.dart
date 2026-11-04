import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

class OrdersState extends Equatable {
  const OrdersState({
    this.orders = const [],
    this.status,
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
    this.failure,
  });

  final List<Order> orders;
  final OrderStatus? status;
  final int page;
  final bool hasMore;
  final bool loading;
  final AppFailure? failure;

  @override
  List<Object?> get props => [orders, status, page, hasMore, loading, failure];
}

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this._repo) : super(const OrdersState());

  final OrdersRepository _repo;
  int _generation = 0;

  Future<void> load() => _fetch(reset: true, status: state.status);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _fetch(reset: false, status: state.status);
  }

  Future<void> filter(OrderStatus? status) => _fetch(reset: true, status: status);

  Future<void> _fetch({required bool reset, required OrderStatus? status}) async {
    final gen = ++_generation;
    final page = reset ? 1 : state.page + 1;
    emit(OrdersState(
      orders: reset ? const [] : state.orders,
      status: status,
      page: reset ? 0 : state.page,
      hasMore: reset ? true : state.hasMore,
      loading: true,
    ));
    try {
      final result = await _repo.list(page: page, status: status);
      if (gen != _generation) return;
      emit(OrdersState(
        orders: [...state.orders, ...result.items],
        status: status,
        page: result.page,
        hasMore: result.hasMore,
      ));
    } on AppFailure catch (f) {
      if (gen != _generation) return;
      emit(OrdersState(
        orders: state.orders,
        status: status,
        page: state.page,
        hasMore: state.hasMore,
        failure: f,
      ));
    }
  }
}
