import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('leave')) return Icons.beach_access_outlined;
    if (t.contains('task')) return Icons.task_alt_rounded;
    if (t.contains('event') || t.contains('invite')) return Icons.event_outlined;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final me = await ref.read(currentEmployeeProvider.future);
              if (me != null) {
                await ref.read(notificationActionsProvider).markAllRead(me.id);
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.notifications_none_rounded, title: "You're all caught up")
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = list[i];
                  final isRead = n['is_read'] == true;
                  final createdAt = DateTime.tryParse(n['created_at'] as String? ?? '');
                  return ListTile(
                    tileColor: isRead ? null : Theme.of(context).colorScheme.primary.withOpacity(0.04),
                    leading: Icon(
                      _iconFor(n['title'] as String? ?? ''),
                      color: isRead ? Theme.of(context).textTheme.bodySmall?.color : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      n['title'] as String? ?? 'Notification',
                      style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (n['body'] != null) Text(n['body'] as String),
                        if (createdAt != null)
                          Text(
                            '${Formatters.date(createdAt)} · ${Formatters.time(createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    onTap: () => ref.read(notificationActionsProvider).markRead(n['id'] as String),
                  );
                },
              ),
      ),
    );
  }
}
