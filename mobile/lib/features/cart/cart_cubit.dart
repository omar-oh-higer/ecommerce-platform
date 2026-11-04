import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_core/shop_core.dart';

/// Limits enforced by the API (`POST /orders`): 1-20 lines, 1-100 each.
const kMaxCartLines = 20;
const kMaxLineQuantity = 100;

class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
    this.maxQuantity = kMaxLineQuantity,
  });

  final int productId;
  final String name;
  final Money unitPrice;
  final int quantity;
  final String? imageUrl;

  /// Stock known when it was added: never offer more than this.
  final int maxQuantity;

  Money get lineTotal => unitPrice * quantity;

  CartItem copyWith({int? quantity, int? maxQuantity}) => CartItem(
        productId: productId,
        name: name,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        imageUrl: imageUrl,
        maxQuantity: maxQuantity ?? this.maxQuantity,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'unit_price_cents': unitPrice.cents,
        'quantity': quantity,
        'image_url': imageUrl,
        'max_quantity': maxQuantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        productId: (j['product_id'] as num).toInt(),
        name: j['name'] as String,
        unitPrice: Money((j['unit_price_cents'] as num).toInt()),
        quantity: (j['quantity'] as num).toInt(),
        imageUrl: j['image_url'] as String?,
        maxQuantity: (j['max_quantity'] as num?)?.toInt() ?? kMaxLineQuantity,
      );

  @override
  List<Object?> get props => [productId, name, unitPrice, quantity, imageUrl, maxQuantity];
}

class CartState extends Equatable {
  const CartState([this.items = const []]);
  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  int get totalQuantity => items.fold(0, (s, i) => s + i.quantity);
  Money get total => items.fold(Money.zero, (s, i) => s + i.lineTotal);

  @override
  List<Object?> get props => [items];
}

abstract class CartStorage {
  Future<String?> read();
  Future<void> write(String json);
}

class PrefsCartStorage implements CartStorage {
  static const _key = 'cart_v1';
  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);
  @override
  Future<void> write(String json) async =>
      (await SharedPreferences.getInstance()).setString(_key, json);
}

/// Local shopping cart (the API has no cart endpoint). Survives app restarts.
class CartCubit extends Cubit<CartState> {
  CartCubit(this._storage) : super(const CartState());

  final CartStorage _storage;

  Future<void> load() async {
    try {
      final raw = await _storage.read();
      if (raw == null) return;
      emit(CartState([
        for (final j in (jsonDecode(raw) as List)) CartItem.fromJson((j as Map).cast<String, dynamic>())
      ]));
    } catch (_) {
      // Corrupt data: start with an empty cart.
    }
  }

  /// Returns false when the cart is full (20 lines) or the product can't be bought.
  bool add(Product product, {int quantity = 1}) {
    if (!product.canBuy) return false;
    final max = _limit(product.stock.quantity);
    final items = [...state.items];
    final i = items.indexWhere((e) => e.productId == product.id);
    if (i >= 0) {
      final q = (items[i].quantity + quantity).clamp(1, max);
      items[i] = items[i].copyWith(quantity: q, maxQuantity: max);
    } else {
      if (items.length >= kMaxCartLines) return false;
      items.add(CartItem(
        productId: product.id,
        name: product.name,
        unitPrice: product.price,
        imageUrl: product.imageUrl,
        quantity: quantity.clamp(1, max),
        maxQuantity: max,
      ));
    }
    _set(items);
    return true;
  }

  void setQuantity(int productId, int quantity) {
    final items = <CartItem>[];
    for (final e in state.items) {
      if (e.productId != productId) {
        items.add(e);
      } else if (quantity > 0) {
        items.add(e.copyWith(quantity: quantity.clamp(1, e.maxQuantity)));
      }
    }
    _set(items);
  }

  void remove(int productId) => setQuantity(productId, 0);

  void clear() => _set(<CartItem>[]);

  /// After a 409 the server tells us what is really available: shrink lines.
  void applyAvailability(List<StockProblem> problems) {
    final byId = {for (final p in problems) p.productId: p.available};
    final items = <CartItem>[];
    for (final e in state.items) {
      final available = byId[e.productId];
      if (available == null) {
        items.add(e);
      } else if (available > 0) {
        items.add(e.copyWith(
            quantity: e.quantity > available ? available : e.quantity,
            maxQuantity: available));
      }
    }
    _set(items);
  }

  int _limit(int? stock) => stock == null ? kMaxLineQuantity : stock.clamp(1, kMaxLineQuantity);

  void _set(List<CartItem> items) {
    emit(CartState(items));
    _storage.write(jsonEncode([for (final i in items) i.toJson()]));
  }
}
