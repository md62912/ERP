import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/project.dart';
import '../../../core/utils/formatters.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/utils/profile_guard.dart';

Color _projectStatusColor(ProjectStatus s) => switch (s) {
      ProjectStatus.planning => Colors.blueGrey,
      ProjectStatus.active => Colors.green,
      ProjectStatus.onHold => Colors.orange,
      ProjectStatus.completed => Colors.teal,
      ProjectStatus.cancelled => Colors.red,
    };

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
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(error: e),
          data: (list) => list.isEmpty
              ? const EmptyState(icon: Icons.folder_open_outlined, title: 'No projects yet')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ProjectCard(project: list[i]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateProjectDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateProjectDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    ProjectStatus status = ProjectStatus.planning;
    DateTime? startDate;
    DateTime? endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Project name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
                const SizedBox(height: 8),
                DropdownButtonFormField<ProjectStatus>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [for (final s in ProjectStatus.values) DropdownMenuItem(value: s, child: Text(s.name))],
                  onChanged: (v) => setState(() => status = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Budget (optional)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => startDate = picked);
                  },
                  child: Text(startDate == null ? 'Pick start date (optional)' : 'Start: ${Formatters.date(startDate)}'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => endDate = picked);
                  },
                  child: Text(endDate == null ? 'Pick end date (optional)' : 'End: ${Formatters.date(endDate)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: nameCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      final me = await ref.read(currentEmployeeProvider.future);
                      if (me == null) {
                        notifyProfileNotReady(context);
                        return;
                      }
                      try {
                        await ref.read(projectActionsProvider).createProject(
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              ownerId: me.id,
                              status: status,
                              startDate: startDate,
                              endDate: endDate,
                              budget: double.tryParse(budgetCtrl.text),
                            );
                        if (context.mounted) Navigator.pop(context);
                        ref.invalidate(projectListProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create project: ${friendlyError(e)}')));
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
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final color = _projectStatusColor(project.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/projects/${project.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.folder_special_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(project.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  StatusPill(label: project.status.name, color: color),
                ],
              ),
              if (project.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (project.endDate != null || project.budget != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (project.endDate != null)
                      _MetaChip(icon: Icons.event_outlined, label: 'Due ${Formatters.date(project.endDate)}'),
                    if (project.budget != null)
                      _MetaChip(icon: Icons.attach_money_rounded, label: Formatters.currency(project.budget)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
