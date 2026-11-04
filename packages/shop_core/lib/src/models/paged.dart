import 'package:equatable/equatable.dart';

/// One page of a paginated list (`{data, meta}` from the API).
class Paged<T> extends Equatable {
  const Paged({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;

  factory Paged.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Paged(
      items: [
        for (final raw in (json['data'] as List? ?? const []))
          parse((raw as Map).cast<String, dynamic>())
      ],
      page: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [items, page, lastPage, total];
}
