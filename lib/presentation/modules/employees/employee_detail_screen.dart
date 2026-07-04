import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/employee_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/employee.dart';
import 'employee_form_screen.dart';

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
      await ref.read(documentActionsProvider).upload(
            employeeId: employeeId,
            fileName: file.name,
            bytes: file.bytes!,
          );
      ref.invalidate(employeeDocumentsProvider(employeeId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open document: $e')));
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load employee: $e')),
        data: (employee) {
          final canManage = _canManage(ref, employee);
          final documents = ref.watch(employeeDocumentsProvider(employeeId));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  child: Text(
                    employee.firstName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(employee.fullName, style: Theme.of(context).textTheme.titleLarge),
              ),
              Center(
                child: Text(
                  employee.designation ?? employee.role.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ),
              const SizedBox(height: 24),
              _InfoTile(label: 'Employee Code', value: employee.empCode),
              _InfoTile(label: 'Email', value: employee.email),
              _InfoTile(label: 'Phone', value: employee.phone ?? '-'),
              _InfoTile(label: 'Join Date', value: Formatters.date(employee.joinDate)),
              _InfoTile(label: 'Employment Type', value: employee.employmentType?.name ?? '-'),
              _InfoTile(label: 'Status', value: employee.status.name),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documents', style: Theme.of(context).textTheme.titleMedium),
                  if (canManage)
                    TextButton.icon(
                      onPressed: () => _uploadDocument(context, ref, employeeId),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload'),
                    ),
                ],
              ),
              documents.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Could not load documents: $e'),
                data: (docs) => docs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No documents uploaded yet'),
                      )
                    : Column(
                        children: [
                          for (final doc in docs)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.insert_drive_file_outlined),
                              title: Text(doc.docType ?? 'Document'),
                              subtitle: Text(Formatters.date(doc.uploadedAt)),
                              trailing: const Icon(Icons.open_in_new, size: 18),
                              onTap: () => _openDocument(context, ref, doc),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
