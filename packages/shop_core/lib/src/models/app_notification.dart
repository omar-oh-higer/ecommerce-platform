import 'package:equatable/equatable.dart';

/// A notification from `GET /notifications` (named so it does not clash with
/// Flutter's own `Notification` class).
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.payload,
    required this.read,
    this.createdAt,
  });

  /// UUID string, not a number.
  final String id;

  /// `order.placed`, `order.new` or `order.status_changed`. Code relies on it.
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> payload;
  final bool read;
  final DateTime? createdAt;

  /// Order this notification is about (all current types have one).
  int? get orderId => (payload['order_id'] as num?)?.toInt();

  AppNotification markedRead() => AppNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        payload: payload,
        read: true,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'].toString(),
        type: (j['type'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        message: (j['message'] ?? '') as String,
        payload: j['payload'] is Map ? (j['payload'] as Map).cast<String, dynamic>() : const {},
        read: j['read'] == true,
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );

  @override
  List<Object?> get props => [id, type, title, message, payload, read, createdAt];
}
