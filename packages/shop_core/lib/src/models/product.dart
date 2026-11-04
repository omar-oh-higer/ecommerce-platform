import 'package:equatable/equatable.dart';

import 'money.dart';

class Category extends Equatable {
  const Category({required this.id, required this.name, required this.slug, this.productsCount});

  final int id;
  final String name;
  final String slug;
  final int? productsCount;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        slug: (json['slug'] ?? '') as String,
        productsCount: (json['products_count'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [id, name, slug, productsCount];
}

enum StockStatus {
  inStock,
  outOfStock,

  /// The inventory service could not be reached; quantity is unknown.
  unavailable;

  static StockStatus parse(Object? v) => switch (v) {
        'in_stock' => inStock,
        'out_of_stock' => outOfStock,
        _ => unavailable,
      };
}

class Stock extends Equatable {
  const Stock({required this.status, this.quantity});

  final StockStatus status;
  final int? quantity;

  factory Stock.fromJson(Map<String, dynamic>? json) => Stock(
        status: StockStatus.parse(json?['status']),
        quantity: (json?['quantity'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [status, quantity];
}

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.imageUrl,
    this.category,
  });

  final int id;
  final String name;
  final String description;
  final Money price;
  final String? imageUrl;
  final Category? category;
  final Stock stock;

  bool get canBuy => stock.status == StockStatus.inStock;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        description: (json['description'] ?? '') as String,
        price: Money.parse(json['price']),
        imageUrl: json['image_url'] as String?,
        category: json['category'] is Map
            ? Category.fromJson((json['category'] as Map).cast<String, dynamic>())
            : null,
        stock: Stock.fromJson((json['stock'] as Map?)?.cast<String, dynamic>()),
      );

  @override
  List<Object?> get props => [id, name, description, price, imageUrl, category, stock];
}
