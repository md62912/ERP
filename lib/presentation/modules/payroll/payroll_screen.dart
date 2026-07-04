import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/payslip_pdf.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
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
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

Color _payslipStatusColor(String status) => switch (status) {
      'sent' => Colors.blue,
      'acknowledged' => Colors.green,
      _ => Colors.orange,
    };

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref, Map<String, dynamic> payslip) async {
    final me = await ref.read(currentEmployeeProvider.future);
    if (me == null) return;
    try {
      await sharePayslipPdf(payslip: payslip, employeeName: me.fullName, empCode: me.empCode);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate PDF: ${friendlyError(e)}')));
      }
    }
  }

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
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_myPayslipsProvider),
        child: payslips.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(error: e),
          data: (rows) => rows.isEmpty
              ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No payslips yet')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final run = r['payroll_runs'] as Map?;
                    final month = run?['month'] as int?;
                    final year = run?['year'];
                    final status = r['status'] as String? ?? 'generated';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.receipt_long_rounded, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    month == null ? 'Payslip' : '${_monthNames[month]} $year',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Net pay: ${Formatters.currency(r['net_salary'])}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            StatusPill(label: status, color: _payslipStatusColor(status)),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              tooltip: 'Download PDF',
                              onPressed: () => _downloadPdf(context, ref, r),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
