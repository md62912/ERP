import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/auth_provider.dart';
import 'payroll_admin_screen.dart';

final _myPayslipsProvider = FutureProvider.autoDispose((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return <Map<String, dynamic>>[];
  final rows = await SupabaseService.client
      .from(Tables.payslips)
      .select('*, payroll_runs(month, year)')
      .eq('employee_id', me.id)
      .order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

const _monthNames = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslips = ref.watch(_myPayslipsProvider);
    final role = ref.watch(currentUserRoleProvider);
    final canManage = role == UserRole.admin || role == UserRole.hr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Payroll Admin',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PayrollAdminScreen()),
              ),
            ),
        ],
      ),
      body: payslips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load payslips: $e')),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No payslips yet'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final run = r['payroll_runs'] as Map?;
                  final month = run?['month'] as int?;
                  final year = run?['year'];
                  return Card(
                    child: ListTile(
                      title: Text(month == null ? 'Payslip' : '${_monthNames[month]} $year'),
                      subtitle: Text('Net pay: ${Formatters.currency(r['net_salary'])}'),
                      trailing: Chip(label: Text(r['status'] as String? ?? '')),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
