
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shop_core/shop_core.dart';

class MockRepo extends Mock implements NotificationsRepository {}

AppNotification n(String id, {bool read = false}) => AppNotification(
    id: id, type: 'order.placed', title: 't', message: 'm', payload: const {'order_id': 4}, read: read);

void main() {
  test('model reads the real API shape', () {
    final x = AppNotification.fromJson({
      'id': 'cc7922f8-ea17-4c01-be34-d5838f904b94',
      'type': 'order.status_changed',
      'title': 'Order confirmed',
      'message': 'Your order #4 has been confirmed.',
      'payload': {'order_id': 4, 'status': 'confirmed', 'previous_status': 'pending'},
      'read': false,
      'read_at': null,
      'created_at': '2026-11-04T20:40:53+00:00',
    });
    expect(x.orderId, 4);
    expect(x.read, isFalse);
    expect(x.markedRead().read, isTrue);
  });

  test('polling emits the count every interval and survives failures', () {
    fakeAsync((async) {
      final repo = MockRepo();
      var calls = 0;
      when(() => repo.unreadCount()).thenAnswer((_) async {
        calls++;
        if (calls == 2) throw const NetworkFailure('offline');
        return calls;
      });
      final source = PollingNotificationSource(repo, interval: const Duration(seconds: 30));
      final cubit = UnreadCountCubit(source);
      final seen = <int>[];
      cubit.stream.listen(seen.add);

      cubit.start();
      async.elapse(const Duration(seconds: 1));
      async.elapse(const Duration(seconds: 30)); // 2nd call fails: nothing emitted
      async.elapse(const Duration(seconds: 30)); // 3rd call
      expect(seen, [1, 3]);
      expect(cubit.state, 3);

      cubit.stop();
      async.elapse(const Duration(minutes: 5));
      expect(calls, 3, reason: 'no polling after stop (e.g. signed out / app paused)');
    });
  });

  test('markRead updates the list immediately and calls the server once', () async {
    final repo = MockRepo();
    when(() => repo.list(page: any(named: 'page'))).thenAnswer((_) async =>
        Paged(items: [n('a'), n('b')], page: 1, lastPage: 1, total: 2));
    when(() => repo.markRead(any())).thenAnswer((_) async {});
    final cubit = NotificationsCubit(repo);
    await cubit.load();
    expect(cubit.state.unread, 2);
    await cubit.markRead(cubit.state.items.first);
    expect(cubit.state.unread, 1);
    await cubit.markRead(cubit.state.items.first); // already read: no 2nd call
    verify(() => repo.markRead('a')).called(1);
  });

  test('markAllRead', () async {
    final repo = MockRepo();
    when(() => repo.list(page: any(named: 'page'))).thenAnswer((_) async =>
        Paged(items: [n('a'), n('b')], page: 1, lastPage: 1, total: 2));
    when(() => repo.markAllRead()).thenAnswer((_) async {});
    final cubit = NotificationsCubit(repo);
    await cubit.load();
    await cubit.markAllRead();
    expect(cubit.state.unread, 0);
    verify(() => repo.markAllRead()).called(1);
  });
}
