import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/project_provider.dart';
import '../../../domain/entities/project.dart';
import '../../../core/utils/formatters.dart';

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(projectListProvider),
        child: projects.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load projects: $e')),
          data: (list) => list.isEmpty
              ? const Center(child: Text('No projects yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ProjectCard(project: list[i]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: create-project form (RLS restricts writes to owner/hr/admin/manager)
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  Color _statusColor(ProjectStatus s) => switch (s) {
        ProjectStatus.planning => Colors.blueGrey,
        ProjectStatus.active => Colors.green,
        ProjectStatus.onHold => Colors.orange,
        ProjectStatus.completed => Colors.teal,
        ProjectStatus.cancelled => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(project.status);
    return Card(
      child: ListTile(
        onTap: () => context.push('/projects/${project.id}'),
        title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (project.endDate != null)
                  Text('Due ${Formatters.date(project.endDate)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(
            project.status.name,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
