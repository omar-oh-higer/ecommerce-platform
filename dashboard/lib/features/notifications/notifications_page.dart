import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../../core/widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: BlocBuilder<NotificationsCubit, NotificationsState>(builder: (context, s) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            IconButton(tooltip: 'Refresh', onPressed: () async {
              await cubit.load();
              if (context.mounted) context.read<UnreadCountCubit>().refresh();
            }, icon: const Icon(Icons.refresh)),
            TextButton(
              onPressed: s.unread == 0
                  ? null
                  : () async {
                      await cubit.markAllRead();
                      if (context.mounted) context.read<UnreadCountCubit>().refresh();
                    },
              child: const Text('Mark all read'),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(child: _body(context, s, cubit)),
        ]);
      }),
    );
  }

  Widget _body(BuildContext context, NotificationsState s, NotificationsCubit cubit) {
    if (s.loading && s.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (s.failure != null && s.items.isEmpty) return ErrorView(s.failure!, onRetry: cubit.load);
    if (s.items.isEmpty) return const Center(child: Text('No notifications yet.'));
    return Card(
      child: ListView.separated(
        itemCount: s.items.length + (s.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == s.items.length) {
            return TextButton(onPressed: cubit.loadMore, child: const Text('Load more'));
          }
          final n = s.items[i];
          return ListTile(
            tileColor: n.read ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
            leading: Icon(n.type == 'order.new' ? Icons.shopping_bag_outlined : Icons.local_shipping_outlined),
            title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
            subtitle: Text('${n.message}\n${formatDate(n.createdAt)}'),
            isThreeLine: true,
            trailing: n.read ? null : const Icon(Icons.circle, size: 10),
            onTap: () async {
              await cubit.markRead(n);
              if (!context.mounted) return;
              context.read<UnreadCountCubit>().set(cubit.state.unread);
              final id = n.orderId;
              if (id != null) context.go('/orders/$id');
            },
          );
        },
      ),
    );
  }
}
