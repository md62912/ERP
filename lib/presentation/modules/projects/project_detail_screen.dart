import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';
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

Color _taskStatusColor(TaskStatus s) => switch (s) {
      TaskStatus.todo => Colors.blueGrey,
      TaskStatus.inProgress => Colors.blue,
      TaskStatus.inReview => Colors.purple,
      TaskStatus.blocked => Colors.red,
      TaskStatus.done => Colors.green,
    };

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

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
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  final String projectId;
  const _TasksTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(projectTasksProvider(projectId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(projectTasksProvider(projectId)),
      child: tasks.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.checklist_rounded, title: 'No tasks yet')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final t = list[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          Container(width: 4, height: 40, decoration: BoxDecoration(color: _priorityColor(t.priority), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(t.title, style: Theme.of(context).textTheme.titleSmall),
                                if (t.dueDate != null)
                                  Text('Due ${Formatters.date(t.dueDate)}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          DropdownButton<TaskStatus>(
                            value: t.status,
                            underline: const SizedBox.shrink(),
                            icon: const Icon(Icons.expand_more, size: 18),
                            items: [
                              for (final s in TaskStatus.values)
                                DropdownMenuItem(
                                  value: s,
                                  child: StatusPill(label: s.name, color: _taskStatusColor(s)),
                                ),
                            ],
                            onChanged: (newStatus) async {
                              if (newStatus == null) return;
                              await ref.read(taskRepositoryProvider).updateStatus(t.id, newStatus);
                              ref.invalidate(projectTasksProvider(projectId));
                              ref.invalidate(myTasksProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
