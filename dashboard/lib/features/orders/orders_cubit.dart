import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

class OrdersState extends Equatable {
  const OrdersState({
    this.orders = const [],
    this.status,
    this.page = 1,
    this.lastPage = 1,
    this.total = 0,
    this.loading = false,
    this.failure,
    this.countsByStatus = const {},
  });

  final List<Order> orders;
  final OrderStatus? status;
  final int page;
  final int lastPage;
  final int total;
  final bool loading;
  final AppFailure? failure;

  /// Real totals from the server (one cheap request per status).
  final Map<OrderStatus, int> countsByStatus;

  @override
  List<Object?> get props => [orders, status, page, lastPage, total, loading, failure, countsByStatus];
}

/// Page-based list (a table has Previous / Next, not infinite scroll).
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this._repo) : super(const OrdersState());

  final OrdersRepository _repo;
  int _generation = 0;

  Future<void> load({OrderStatus? status, int page = 1, bool keepFilter = false}) async {
    final filter = keepFilter ? state.status : status;
    final gen = ++_generation;
    emit(OrdersState(
      orders: state.orders,
      status: filter,
      page: page,
      lastPage: state.lastPage,
      total: state.total,
      loading: true,
      countsByStatus: state.countsByStatus,
    ));
    try {
      final result = await _repo.list(page: page, perPage: 15, status: filter);
      if (gen != _generation) return;
      emit(OrdersState(
        orders: result.items,
        status: filter,
        page: result.page,
        lastPage: result.lastPage,
        total: result.total,
        countsByStatus: state.countsByStatus,
      ));
      _loadCounts(gen);
    } on AppFailure catch (f) {
      if (gen != _generation) return;
      emit(OrdersState(
          orders: state.orders, status: filter, page: page, lastPage: state.lastPage, failure: f,
          countsByStatus: state.countsByStatus));
    }
  }

  Future<void> refresh() => load(status: state.status, page: state.page);

  Future<void> _loadCounts(int gen) async {
    try {
      final results = await Future.wait([
        for (final s in OrderStatus.values) _repo.list(perPage: 1, status: s),
      ]);
      if (isClosed || gen != _generation) return;
      final counts = {for (var i = 0; i < results.length; i++) OrderStatus.values[i]: results[i].total};
      emit(OrdersState(
        orders: state.orders, status: state.status, page: state.page, lastPage: state.lastPage,
        total: state.total, loading: state.loading, failure: state.failure, countsByStatus: counts,
      ));
    } on AppFailure {
      // The cards are decoration; ignore failures.
    }
  }
}
