import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/employee_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/employee.dart';
import 'employee_form_screen.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeeListProvider);
    final role = ref.watch(currentUserRoleProvider);
    final canManage = role == UserRole.admin || role == UserRole.hr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, code, email...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref.read(employeeSearchProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: employees.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load employees: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No employees found'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _EmployeeTile(employee: list[index]),
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final Employee employee;
  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(employee.firstName.substring(0, 1).toUpperCase())),
      title: Text(employee.fullName),
      subtitle: Text('${employee.designation ?? employee.role.name} · ${employee.empCode}'),
      trailing: _StatusChip(status: employee.status),
      onTap: () => context.push('/employees/${employee.id}'),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final EmployeeStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      EmployeeStatus.active => Colors.green,
      EmployeeStatus.onLeave => Colors.orange,
      EmployeeStatus.inactive => Colors.grey,
      EmployeeStatus.terminated => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status.name, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
