import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../models/paged.dart';
import '../models/product.dart';
import '../network/api_client.dart';

class CatalogRepository {
  CatalogRepository(this.api);
  final ApiClient api;

  Future<List<Category>> categories() async {
    final json = await api.getJson('/categories');
    return [
      for (final c in (json['data'] as List)) Category.fromJson((c as Map).cast<String, dynamic>())
    ];
  }

  Future<Paged<Product>> products({
    int page = 1,
    int perPage = 15,
    int? categoryId,
    String? search,
  }) async {
    final json = await api.getJson('/products', query: {
      'page': page,
      'per_page': perPage,
      'category_id': ?categoryId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
    return Paged.fromJson(json, Product.fromJson);
  }

  Future<Product> product(int id) async {
    final json = await api.getJson('/products/$id');
    return Product.fromJson((json['data'] as Map).cast<String, dynamic>());
  }

  // ---- Administrator only ----

  /// Throws [ValidationFailure] when the name already exists.
  Future<Category> createCategory(String name) async {
    final json = await api.postJson('/categories', body: {'name': name.trim()});
    return Category.fromJson((json['data'] as Map).cast<String, dynamic>());
  }

  /// Sends a multipart request. On 422 / 503 nothing is saved.
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required int quantity,
    required Uint8List imageBytes,
    required String imageFilename,
  }) async {
    final ext = imageFilename.split('.').last.toLowerCase();
    final subtype = ext == 'jpg' ? 'jpeg' : ext;
    final form = FormData.fromMap({
      'category_id': categoryId,
      'name': name.trim(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      'price': price,
      'quantity': quantity,
      'image': MultipartFile.fromBytes(imageBytes,
          filename: imageFilename, contentType: MediaType('image', subtype)),
    });
    final json = await api.postMultipart('/products', form);
    return Product.fromJson((json['data'] as Map).cast<String, dynamic>());
  }

  Future<Product> updateStock(int productId, int quantity) async {
    final json = await api.patchJson('/products/$productId/stock', body: {'quantity': quantity});
    return Product.fromJson((json['data'] as Map).cast<String, dynamic>());
  }
}
