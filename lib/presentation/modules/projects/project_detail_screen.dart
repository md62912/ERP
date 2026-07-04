import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/project.dart';

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

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.low => Colors.grey,
        TaskPriority.medium => Colors.blue,
        TaskPriority.high => Colors.orange,
        TaskPriority.urgent => Colors.red,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(projectTasksProvider(projectId));

    return tasks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load tasks: $e')),
      data: (list) => list.isEmpty
          ? const Center(child: Text('No tasks yet'))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 6,
                    backgroundColor: _priorityColor(t.priority),
                  ),
                  title: Text(t.title),
                  subtitle: Text(t.dueDate != null ? 'Due ${Formatters.date(t.dueDate)}' : t.status.name),
                  trailing: DropdownButton<TaskStatus>(
                    value: t.status,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final s in TaskStatus.values)
                        DropdownMenuItem(value: s, child: Text(s.name)),
                    ],
                    onChanged: (newStatus) async {
                      if (newStatus == null) return;
                      await ref.read(taskRepositoryProvider).updateStatus(t.id, newStatus);
                      ref.invalidate(projectTasksProvider(projectId));
                      ref.invalidate(myTasksProvider);
                    },
                  ),
                );
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

    return milestones.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load milestones: $e')),
      data: (list) => list.isEmpty
          ? const Center(child: Text('No milestones yet'))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final m = list[i];
                final done = m['status'] == 'completed';
                return ListTile(
                  leading: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done ? Colors.green : Colors.grey,
                  ),
                  title: Text(m['name'] as String),
                  subtitle: m['due_date'] != null ? Text('Due ${m['due_date']}') : null,
                );
              },
            ),
    );
  }
}
