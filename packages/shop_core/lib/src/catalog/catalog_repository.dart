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
}
