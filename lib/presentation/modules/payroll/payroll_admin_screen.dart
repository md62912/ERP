import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/payroll_admin_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../../core/utils/error_helper.dart';

const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class PayrollAdminScreen extends ConsumerWidget {
  const PayrollAdminScreen({super.key});

  Future<void> _createRun(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    int month = now.month;
    int year = now.year;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Payroll Run'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: month,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text(_monthNames[m])),
                  ],
                  onChanged: (v) => setState(() => month = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [
                    for (var y = now.year - 1; y <= now.year + 1; y++)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) => setState(() => year = v!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(payrollActionsProvider).createRun(month: month, year: year);
      ref.invalidate(payrollRunsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create run: ${friendlyError(e)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(payrollRunsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll Admin')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(payrollRunsProvider),
        child: runs.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(error: e),
          data: (list) => list.isEmpty
              ? const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No payroll runs yet')
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _RunCard(run: list[i]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createRun(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Run'),
      ),
    );
  }
}

class _RunCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> run;
  const _RunCard({required this.run});

  @override
  ConsumerState<_RunCard> createState() => _RunCardState();
}

class _RunCardState extends ConsumerState<_RunCard> {
  bool _processing = false;

  Color _statusColor(String status) => switch (status) {
        'draft' => Colors.grey,
        'processing' => Colors.orange,
        'approved' => Colors.blue,
        'paid' => Colors.green,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final month = run['month'] as int;
    final year = run['year'];
    final status = run['status'] as String;
    final runId = run['id'] as String;
    final payslips = ref.watch(payrollRunPayslipsProvider(runId));

    return Card(
      child: ExpansionTile(
        title: Text('${_monthNames[month]} $year'),
        subtitle: Text(
          run['total_amount'] != null ? 'Total: ${Formatters.currency(run['total_amount'])}' : 'Not yet processed',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration:
              BoxDecoration(color: _statusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 12)),
        ),
        children: [
          payslips.when(
            loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: Text('Error: ${friendlyError(e)}')),
            data: (rows) => rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No payslips generated yet for this run.'),
                  )
                : Column(
                    children: [
                      for (final p in rows)
                        ListTile(
                          dense: true,
                          title: Text(
                            '${(p['employees'] as Map?)?['first_name'] ?? ''} ${(p['employees'] as Map?)?['last_name'] ?? ''}',
                          ),
                          trailing: Text(Formatters.currency(p['net_salary'])),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (status == 'draft')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _processing
                          ? null
                          : () async {
                              setState(() => _processing = true);
                              try {
                                final count = await ref.read(payrollActionsProvider).generatePayslips(runId);
                                ref.invalidate(payrollRunsProvider);
                                ref.invalidate(payrollRunPayslipsProvider(runId));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('Generated $count payslips')));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('Failed: ${friendlyError(e)}')));
                                }
                              } finally {
                                if (mounted) setState(() => _processing = false);
                              }
                            },
                      child: _processing
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Generate Payslips'),
                    ),
                  ),
                if (status == 'processing') ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(payrollActionsProvider).markPaid(runId);
                        ref.invalidate(payrollRunsProvider);
                      },
                      child: const Text('Mark as Paid'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
