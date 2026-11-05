import 'dart:async';

import '../errors/app_failure.dart';
import 'notifications_repository.dart';

/// Where the unread count comes from. Today: polling. When real-time delivery
/// (WebSocket / push) arrives, only a new implementation of this is needed:
/// no screen changes.
abstract class NotificationSource {
  /// Emits the unread count whenever it is known or changes.
  Stream<int> get unreadCount;

  void start();
  void stop();

  /// Ask for a fresh value now (after the user acted, or the app resumed).
  Future<void> refresh();

  /// Dispose for good.
  Future<void> close();
}

class PollingNotificationSource implements NotificationSource {
  PollingNotificationSource(this._repo, {this.interval = const Duration(seconds: 30)});

  final NotificationsRepository _repo;
  final Duration interval;
  final _controller = StreamController<int>.broadcast();
  Timer? _timer;

  @override
  Stream<int> get unreadCount => _controller.stream;

  @override
  void start() {
    _timer?.cancel();
    refresh();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> refresh() async {
    try {
      final count = await _repo.unreadCount();
      if (!_controller.isClosed) _controller.add(count);
    } on AppFailure {
      // Polling must never disturb the user: keep the last known count.
    }
  }

  @override
  Future<void> close() async {
    stop();
    await _controller.close();
  }
}
