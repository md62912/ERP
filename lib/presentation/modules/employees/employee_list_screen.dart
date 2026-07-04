import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/employee_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/employee.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import 'employee_form_screen.dart';

Color _employeeStatusColor(EmployeeStatus status) => switch (status) {
      EmployeeStatus.active => Colors.green,
      EmployeeStatus.onLeave => Colors.orange,
      EmployeeStatus.inactive => Colors.grey,
      EmployeeStatus.terminated => Colors.red,
    };

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
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, code, email...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => ref.read(employeeSearchProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(employeeListProvider),
        child: employees.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(error: e),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(icon: Icons.people_outline, title: 'No employees found');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _EmployeeCard(employee: list[index]),
            );
          },
        ),
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

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  const _EmployeeCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    final color = _employeeStatusColor(employee.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/employees/${employee.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                child: Text(
                  employee.firstName.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.fullName, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.designation ?? employee.role.name} · ${employee.empCode}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: employee.status.name, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
