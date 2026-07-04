import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/employee_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/employee.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/status_pill.dart';
import 'employee_form_screen.dart';
import '../../../core/utils/error_helper.dart';

Color _employeeStatusColor(EmployeeStatus status) => switch (status) {
      EmployeeStatus.active => Colors.green,
      EmployeeStatus.onLeave => Colors.orange,
      EmployeeStatus.inactive => Colors.grey,
      EmployeeStatus.terminated => Colors.red,
    };

class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  bool _canManage(WidgetRef ref, Employee employee) {
    final role = ref.watch(currentUserRoleProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    return role == UserRole.admin || role == UserRole.hr || me?.id == employee.id;
  }

  Future<void> _uploadDocument(BuildContext context, WidgetRef ref, String employeeId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    try {
      await ref.read(documentActionsProvider).upload(employeeId: employeeId, fileName: file.name, bytes: file.bytes!);
      ref.invalidate(employeeDocumentsProvider(employeeId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${friendlyError(e)}')));
      }
    }
  }

  Future<void> _openDocument(BuildContext context, WidgetRef ref, EmployeeDocument doc) async {
    if (doc.fileUrl == null) return;
    try {
      final signedUrl = await ref.read(documentActionsProvider).signedUrlFor(doc.fileUrl!);
      await launchUrl(Uri.parse(signedUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open document: ${friendlyError(e)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeAsync = ref.watch(employeeByIdProvider(employeeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Profile'),
        actions: [
          employeeAsync.maybeWhen(
            data: (employee) => _canManage(ref, employee)
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => EmployeeFormScreen(existing: employee)),
                      );
                      if (saved == true) ref.invalidate(employeeByIdProvider(employeeId));
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: employeeAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (employee) {
          final canManage = _canManage(ref, employee);
          final documents = ref.watch(employeeDocumentsProvider(employeeId));
          final statusColor = _employeeStatusColor(employee.status);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        child: Text(
                          employee.firstName.substring(0, 1).toUpperCase(),
                          style: TextStyle(fontSize: 26, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(employee.fullName, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(employee.designation ?? employee.role.name, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 10),
                      StatusPill(label: employee.status.name, color: statusColor),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.badge_outlined, label: 'Employee Code', value: employee.empCode),
                      const Divider(height: 1),
                      _InfoRow(icon: Icons.email_outlined, label: 'Email', value: employee.email),
                      const Divider(height: 1),
                      _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: employee.phone ?? '-'),
                      const Divider(height: 1),
                      _InfoRow(icon: Icons.calendar_today_outlined, label: 'Join Date', value: Formatters.date(employee.joinDate)),
                      const Divider(height: 1),
                      _InfoRow(icon: Icons.work_outline, label: 'Employment Type', value: employee.employmentType?.name ?? '-'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documents', style: Theme.of(context).textTheme.titleMedium),
                  if (canManage)
                    TextButton.icon(
                      onPressed: () => _uploadDocument(context, ref, employeeId),
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Upload'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              documents.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LoadingView()),
                error: (e, _) => ErrorView(error: e),
                data: (docs) => docs.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text('No documents uploaded yet', style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ),
                      )
                    : Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final doc in docs)
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.insert_drive_file_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                                ),
                                title: Text(doc.docType ?? 'Document', style: Theme.of(context).textTheme.titleSmall),
                                subtitle: Text(Formatters.date(doc.uploadedAt)),
                                trailing: const Icon(Icons.open_in_new, size: 18),
                                onTap: () => _openDocument(context, ref, doc),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
