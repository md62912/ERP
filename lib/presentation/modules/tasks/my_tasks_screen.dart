import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/project.dart';

class MyTasksScreen extends ConsumerWidget {
  const MyTasksScreen({super.key});

  static const _statusOrder = [
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.inReview,
    TaskStatus.blocked,
    TaskStatus.done,
  ];

  static const _statusLabels = {
    TaskStatus.todo: 'To Do',
    TaskStatus.inProgress: 'In Progress',
    TaskStatus.inReview: 'In Review',
    TaskStatus.blocked: 'Blocked',
    TaskStatus.done: 'Done',
  };

  Future<void> _logTime(BuildContext context, WidgetRef ref, ProjectTask task) async {
    final hoursCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log time · ${task.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hoursCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Hours'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final hours = double.tryParse(hoursCtrl.text);
              if (hours == null || hours <= 0) return;
              final me = await ref.read(currentEmployeeProvider.future);
              if (me == null) return;
              await ref.read(taskRepositoryProvider).logTime(
                    taskId: task.id,
                    employeeId: me.id,
                    hours: hours,
                    note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.low => Colors.grey,
        TaskPriority.medium => Colors.blue,
        TaskPriority.high => Colors.orange,
        TaskPriority.urgent => Colors.red,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(myTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTasksProvider),
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load tasks: $e')),
          data: (tasks) {
            if (tasks.isEmpty) {
              return const Center(child: Text('No tasks assigned to you'));
            }
            final grouped = {
              for (final s in _statusOrder) s: tasks.where((t) => t.status == s).toList(),
            };
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final status in _statusOrder)
                  if (grouped[status]!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        '${_statusLabels[status]} (${grouped[status]!.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    for (final task in grouped[status]!)
                      ListTile(
                        leading: CircleAvatar(radius: 6, backgroundColor: _priorityColor(task.priority)),
                        title: Text(task.title),
                        subtitle: task.dueDate != null ? Text('Due ${Formatters.date(task.dueDate)}') : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.timer_outlined),
                          tooltip: 'Log time',
                          onPressed: () => _logTime(context, ref, task),
                        ),
                        onTap: () async {
                          final nextIndex = (_statusOrder.indexOf(task.status) + 1).clamp(0, _statusOrder.length - 1);
                          await ref.read(taskRepositoryProvider).updateStatus(task.id, _statusOrder[nextIndex]);
                          ref.invalidate(myTasksProvider);
                        },
                      ),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}
