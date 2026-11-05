import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'notification_source.dart';

/// Number shown on the bell badge.
class UnreadCountCubit extends Cubit<int> {
  UnreadCountCubit(this._source) : super(0) {
    _sub = _source.unreadCount.listen(emit);
  }

  final NotificationSource _source;
  late final StreamSubscription<int> _sub;

  void start() => _source.start();
  void stop() => _source.stop();
  Future<void> refresh() => _source.refresh();

  /// Reset when the user signs out so the next user never sees a stale badge.
  void reset() {
    _source.stop();
    emit(0);
  }

  /// Used right after the user changes something locally.
  void set(int count) => emit(count < 0 ? 0 : count);

  @override
  Future<void> close() async {
    await _sub.cancel();
    await _source.close();
    return super.close();
  }
}
