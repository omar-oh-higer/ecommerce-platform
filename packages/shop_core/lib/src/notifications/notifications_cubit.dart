import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../errors/app_failure.dart';
import '../models/app_notification.dart';
import 'notifications_repository.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
    this.failure,
  });

  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final bool loading;
  final AppFailure? failure;

  int get unread => items.where((n) => !n.read).length;

  @override
  List<Object?> get props => [items, page, hasMore, loading, failure];
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._repo) : super(const NotificationsState());

  final NotificationsRepository _repo;

  Future<void> load() => _fetch(reset: true);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final page = reset ? 1 : state.page + 1;
    emit(NotificationsState(
      items: state.items, // keep showing the old list while refreshing
      page: reset ? 0 : state.page,
      hasMore: reset ? true : state.hasMore,
      loading: true,
    ));
    try {
      final result = await _repo.list(page: page);
      emit(NotificationsState(
        items: [if (!reset) ...state.items, ...result.items],
        page: result.page,
        hasMore: result.hasMore,
      ));
    } on AppFailure catch (f) {
      emit(NotificationsState(
          items: state.items, page: state.page, hasMore: state.hasMore, failure: f));
    }
  }

  /// Marks one as read: instantly in the list, then on the server. If the
  /// server refuses, the next load shows the truth again.
  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    _replace(n.id, (x) => x.markedRead());
    try {
      await _repo.markRead(n.id);
    } on AppFailure {
      // Keep the optimistic state; it is corrected on the next refresh.
    }
  }

  Future<void> markAllRead() async {
    emit(NotificationsState(
      items: [for (final n in state.items) n.markedRead()],
      page: state.page,
      hasMore: state.hasMore,
    ));
    try {
      await _repo.markAllRead();
    } on AppFailure {
      await load();
    }
  }

  void _replace(String id, AppNotification Function(AppNotification) f) {
    emit(NotificationsState(
      items: [for (final n in state.items) n.id == id ? f(n) : n],
      page: state.page,
      hasMore: state.hasMore,
    ));
  }
}
