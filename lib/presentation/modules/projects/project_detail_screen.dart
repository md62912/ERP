import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/project.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/kanban_board.dart';
import '../../shared/widgets/status_pill.dart';

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

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  Future<void> _showCreateTaskDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? assigneeId;
    TaskPriority priority = TaskPriority.medium;
    DateTime? dueDate;

    final employees = await ref.read(employeeListProvider.future);
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: assigneeId,
                  decoration: const InputDecoration(labelText: 'Assignee'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— Unassigned —')),
                    for (final e in employees) DropdownMenuItem(value: e.id, child: Text(e.fullName)),
                  ],
                  onChanged: (v) => setState(() => assigneeId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TaskPriority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [for (final p in TaskPriority.values) DropdownMenuItem(value: p, child: Text(p.name))],
                  onChanged: (v) => setState(() => priority = v!),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => dueDate = picked);
                  },
                  child: Text(dueDate == null ? 'Pick due date (optional)' : 'Due: ${Formatters.date(dueDate)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: titleCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      final me = await ref.read(currentEmployeeProvider.future);
                      if (me == null) return;
                      try {
                        await ref.read(taskRepositoryProvider).createTask(
                              projectId: projectId,
                              title: titleCtrl.text.trim(),
                              description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              assigneeId: assigneeId,
                              priority: priority,
                              dueDate: dueDate,
                              createdBy: me.id,
                            );
                        if (context.mounted) Navigator.pop(context);
                        ref.invalidate(projectTasksProvider(projectId));
                        ref.invalidate(myTasksProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create task: $e')));
                        }
                      }
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectByIdProvider(projectId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: project.when(
            data: (p) => Text(p.name),
            loading: () => const Text('Project'),
            error: (_, __) => const Text('Project'),
          ),
          bottom: const TabBar(tabs: [Tab(text: 'Tasks'), Tab(text: 'Milestones')]),
        ),
        body: TabBarView(
          children: [
            _TasksTab(projectId: projectId),
            _MilestonesTab(projectId: projectId),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateTaskDialog(context, ref),
          child: const Icon(Icons.add_task_rounded),
        ),
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  final String projectId;
  const _TasksTab({required this.projectId});

  Widget _buildCard(BuildContext context, ProjectTask task) {
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
            if (task.dueDate != null) ...[
              const SizedBox(height: 6),
              Text('Due ${Formatters.date(task.dueDate)}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(projectTasksProvider(projectId));

    return tasks.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e),
      data: (list) => list.isEmpty
          ? const EmptyState(icon: Icons.checklist_rounded, title: 'No tasks yet')
          : KanbanBoard<ProjectTask, TaskStatus>(
              columns: _statusColumns,
              items: list,
              statusOf: (t) => t.status,
              cardBuilder: (context, task) => _buildCard(context, task),
              onStatusChanged: (task, newStatus) async {
                if (task.status == newStatus) return;
                try {
                  await ref.read(taskRepositoryProvider).updateStatus(task.id, newStatus);
                  ref.invalidate(projectTasksProvider(projectId));
                  ref.invalidate(myTasksProvider);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("You don't have permission to update tasks on this project")),
                  );
                }
              },
            ),
    );
  }
}

class _MilestonesTab extends ConsumerWidget {
  final String projectId;
  const _MilestonesTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(projectMilestonesProvider(projectId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(projectMilestonesProvider(projectId)),
      child: milestones.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.flag_outlined, title: 'No milestones yet')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final m = list[i];
                  final done = m['status'] == 'completed';
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: done ? Colors.green : Colors.grey,
                      ),
                      title: Text(m['name'] as String, style: Theme.of(context).textTheme.titleSmall),
                      subtitle: m['due_date'] != null ? Text('Due ${m['due_date']}') : null,
                      trailing: StatusPill(label: done ? 'completed' : 'pending', color: done ? Colors.green : Colors.orange),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
