import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../catalog/product_widgets.dart';
import '../orders/order_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) context.read<NotificationsCubit>().loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keep the bell badge in step with what the user just did.
  void _syncBadge(BuildContext context) =>
      context.read<UnreadCountCubit>().set(context.read<NotificationsCubit>().state.unread);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, s) => TextButton(
              onPressed: s.unread == 0
                  ? null
                  : () async {
                      await cubit.markAllRead();
                      if (context.mounted) context.read<UnreadCountCubit>().refresh();
                    },
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(builder: (context, s) {
        if (s.loading && s.items.isEmpty) return const Center(child: CircularProgressIndicator());
        if (s.failure != null && s.items.isEmpty) return ErrorView(s.failure!, onRetry: cubit.load);
        if (s.items.isEmpty) return const Center(child: Text('No notifications yet.'));
        return RefreshIndicator(
          onRefresh: () async {
            await cubit.load();
            if (context.mounted) context.read<UnreadCountCubit>().refresh();
          },
          child: ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: s.items.length + (s.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == s.items.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: s.failure != null
                        ? TextButton(onPressed: cubit.loadMore, child: const Text('Retry'))
                        : const CircularProgressIndicator(),
                  ),
                );
              }
              final n = s.items[i];
              return ListTile(
                tileColor: n.read ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                leading: Icon(_icon(n.type)),
                title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text('${n.message}\n${formatDate(n.createdAt)}'),
                isThreeLine: true,
                trailing: n.read ? null : const Icon(Icons.circle, size: 10),
                onTap: () async {
                  await cubit.markRead(n);
                  if (!context.mounted) return;
                  _syncBadge(context);
                  final id = n.orderId;
                  if (id != null) context.push('/orders/$id');
                },
              );
            },
          ),
        );
      }),
    );
  }

  IconData _icon(String type) => switch (type) {
        'order.placed' => Icons.receipt_long,
        'order.status_changed' => Icons.local_shipping_outlined,
        _ => Icons.notifications_outlined,
      };
}
