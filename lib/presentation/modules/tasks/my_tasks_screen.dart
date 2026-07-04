import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/project.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';

Color _priorityColor(TaskPriority p) => switch (p) {
      TaskPriority.low => Colors.blueGrey,
      TaskPriority.medium => Colors.blue,
      TaskPriority.high => Colors.orange,
      TaskPriority.urgent => Colors.red,
    };

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

  static const _statusIcons = {
    TaskStatus.todo: Icons.radio_button_unchecked,
    TaskStatus.inProgress: Icons.autorenew_rounded,
    TaskStatus.inReview: Icons.rate_review_outlined,
    TaskStatus.blocked: Icons.block_rounded,
    TaskStatus.done: Icons.check_circle_rounded,
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
            const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(myTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTasksProvider),
        child: tasksAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(error: e),
          data: (tasks) {
            if (tasks.isEmpty) {
              return const EmptyState(icon: Icons.task_alt_rounded, title: 'No tasks assigned to you');
            }
            final grouped = {
              for (final s in _statusOrder) s: tasks.where((t) => t.status == s).toList(),
            };
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                for (final status in _statusOrder)
                  if (grouped[status]!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                      child: Row(
                        children: [
                          Icon(_statusIcons[status], size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
                          const SizedBox(width: 6),
                          Text(
                            '${_statusLabels[status]} · ${grouped[status]!.length}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    for (final task in grouped[status]!)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 4,
                            height: 36,
                            decoration: BoxDecoration(color: _priorityColor(task.priority), borderRadius: BorderRadius.circular(2)),
                          ),
                          title: Text(task.title, style: Theme.of(context).textTheme.titleSmall),
                          subtitle: task.dueDate != null ? Text('Due ${Formatters.date(task.dueDate)}') : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusPill(label: task.priority.name, color: _priorityColor(task.priority)),
                              IconButton(
                                icon: const Icon(Icons.timer_outlined, size: 20),
                                tooltip: 'Log time',
                                onPressed: () => _logTime(context, ref, task),
                              ),
                            ],
                          ),
                          onTap: () async {
                            final nextIndex = (_statusOrder.indexOf(task.status) + 1).clamp(0, _statusOrder.length - 1);
                            await ref.read(taskRepositoryProvider).updateStatus(task.id, _statusOrder[nextIndex]);
                            ref.invalidate(myTasksProvider);
                          },
                        ),
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
