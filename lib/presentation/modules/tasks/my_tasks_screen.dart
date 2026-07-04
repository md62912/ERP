import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/project.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/kanban_board.dart';

Color _priorityColor(TaskPriority p) => switch (p) {
      TaskPriority.low => Colors.blueGrey,
      TaskPriority.medium => Colors.blue,
      TaskPriority.high => Colors.orange,
      TaskPriority.urgent => Colors.red,
    };

const _statusColumns = [
  KanbanColumnDef(status: TaskStatus.todo, label: 'To Do', icon: Icons.radio_button_unchecked, color: Colors.blueGrey),
  KanbanColumnDef(status: TaskStatus.inProgress, label: 'In Progress', icon: Icons.autorenew_rounded, color: Colors.blue),
  KanbanColumnDef(status: TaskStatus.inReview, label: 'In Review', icon: Icons.rate_review_outlined, color: Colors.purple),
  KanbanColumnDef(status: TaskStatus.blocked, label: 'Blocked', icon: Icons.block_rounded, color: Colors.red),
  KanbanColumnDef(status: TaskStatus.done, label: 'Done', icon: Icons.check_circle_rounded, color: Colors.green),
];

class MyTasksScreen extends ConsumerWidget {
  const MyTasksScreen({super.key});

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

  Widget _buildCard(BuildContext context, WidgetRef ref, ProjectTask task) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: _priorityColor(task.priority), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Expanded(child: Text(task.title, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (task.dueDate != null)
                  Text('Due ${Formatters.date(task.dueDate)}', style: Theme.of(context).textTheme.bodySmall)
                else
                  const SizedBox.shrink(),
                InkWell(
                  onTap: () => _logTime(context, ref, task),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.timer_outlined, size: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(myTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Long-press and drag a card to change its status',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      body: tasksAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(icon: Icons.task_alt_rounded, title: 'No tasks assigned to you');
          }
          return KanbanBoard<ProjectTask, TaskStatus>(
            columns: _statusColumns,
            items: tasks,
            statusOf: (t) => t.status,
            cardBuilder: (context, task) => _buildCard(context, ref, task),
            onStatusChanged: (task, newStatus) async {
              if (task.status == newStatus) return;
              await ref.read(taskRepositoryProvider).updateStatus(task.id, newStatus);
              ref.invalidate(myTasksProvider);
            },
          );
        },
      ),
    );
  }
}
