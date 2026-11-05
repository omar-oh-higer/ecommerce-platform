import '../models/app_notification.dart';
import '../models/paged.dart';
import '../network/api_client.dart';

class NotificationsRepository {
  NotificationsRepository(this.api);
  final ApiClient api;

  Future<Paged<AppNotification>> list({int page = 1, int perPage = 20, bool unreadOnly = false}) async {
    final json = await api.getJson('/notifications', query: {
      'page': page,
      'per_page': perPage,
      if (unreadOnly) 'unread': 1,
    });
    return Paged.fromJson(json, AppNotification.fromJson);
  }

  Future<int> unreadCount() async {
    final json = await api.getJson('/notifications/unread-count');
    return ((json['data'] as Map)['unread_count'] as num).toInt();
  }

  Future<void> markRead(String id) => api.patchJson('/notifications/$id/read');

  Future<void> markAllRead() => api.patchJson('/notifications/read-all');
}
