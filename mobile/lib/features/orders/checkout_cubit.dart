import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

import '../cart/cart_cubit.dart';

sealed class CheckoutState extends Equatable {
  const CheckoutState();
  @override
  List<Object?> get props => [];
}

class CheckoutIdle extends CheckoutState {
  const CheckoutIdle();
}

class CheckoutSubmitting extends CheckoutState {
  const CheckoutSubmitting();
}

class CheckoutSuccess extends CheckoutState {
  const CheckoutSuccess(this.order);
  final Order order;
  @override
  List<Object?> get props => [order];
}

/// The order was NOT created. The cart is untouched so the user can retry.
class CheckoutFailed extends CheckoutState {
  const CheckoutFailed(this.failure);
  final AppFailure failure;
  @override
  List<Object?> get props => [failure];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._orders, this._cart) : super(const CheckoutIdle());

  final OrdersRepository _orders;
  final CartCubit _cart;

  /// Ignored while a request is already in flight (no double orders on a
  /// double tap).
  Future<void> submit() async {
    if (state is CheckoutSubmitting || _cart.state.isEmpty) return;
    emit(const CheckoutSubmitting());
    try {
      final order = await _orders.place([
        for (final i in _cart.state.items) OrderLine(i.productId, i.quantity),
      ]);
      _cart.clear();
      emit(CheckoutSuccess(order));
    } on AppFailure catch (f) {
      emit(CheckoutFailed(f));
    }
  }

  /// After "insufficient stock": reduce / drop the lines the server named.
  void adjustCartToStock() {
    final s = state;
    if (s is CheckoutFailed && s.failure is InsufficientStockFailure) {
      _cart.applyAvailability((s.failure as InsufficientStockFailure).items);
    }
    emit(const CheckoutIdle());
  }
}
