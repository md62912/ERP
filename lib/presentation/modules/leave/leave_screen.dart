import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_approval_provider.dart';
import '../../../domain/entities/employee.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';

final _myLeaveRequestsProvider = FutureProvider.autoDispose((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return <Map<String, dynamic>>[];
  final rows = await SupabaseService.client
      .from(Tables.leaveRequests)
      .select('*, leave_types(name)')
      .eq('employee_id', me.id)
      .order('applied_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

final _leaveTypesProvider = FutureProvider.autoDispose((ref) async {
  final rows = await SupabaseService.client.from(Tables.leaveTypes).select();
  return (rows as List).cast<Map<String, dynamic>>();
});

Color _leaveStatusColor(String status) => switch (status) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      'cancelled' => Colors.blueGrey,
      _ => Colors.orange,
    };

IconData _leaveStatusIcon(String status) => switch (status) {
      'approved' => Icons.check_circle,
      'rejected' => Icons.cancel,
      'cancelled' => Icons.block,
      _ => Icons.schedule,
    };

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  Future<void> _showApplyDialog(BuildContext context, WidgetRef ref) async {
    final types = await ref.read(_leaveTypesProvider.future);
    if (!context.mounted || types.isEmpty) return;

    String selectedTypeId = types.first['id'] as String;
    DateTimeRange? range;
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Apply for Leave'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: selectedTypeId,
                items: [
                  for (final t in types)
                    DropdownMenuItem(value: t['id'] as String, child: Text(t['name'] as String)),
                ],
                onChanged: (v) => setState(() => selectedTypeId = v!),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => range = picked);
                },
                label: Text(range == null
                    ? 'Select dates'
                    : '${Formatters.date(range!.start)} → ${Formatters.date(range!.end)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: range == null
                  ? null
                  : () async {
                      final me = await ref.read(currentEmployeeProvider.future);
                      if (me == null) return;
                      final days = range!.end.difference(range!.start).inDays + 1;
                      await SupabaseService.client.from(Tables.leaveRequests).insert({
                        'employee_id': me.id,
                        'leave_type_id': selectedTypeId,
                        'from_date': range!.start.toIso8601String().split('T').first,
                        'to_date': range!.end.toIso8601String().split('T').first,
                        'total_days': days,
                        'reason': reasonCtrl.text,
                      });
                      if (context.mounted) Navigator.pop(context);
                      ref.invalidate(_myLeaveRequestsProvider);
                    },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final canApprove = role == UserRole.admin || role == UserRole.hr || role == UserRole.manager;

    if (!canApprove) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave')),
        body: const _MyRequestsTab(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showApplyDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Apply'),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leave'),
          bottom: const TabBar(tabs: [Tab(text: 'My Requests'), Tab(text: 'Approvals')]),
        ),
        body: const TabBarView(children: [_MyRequestsTab(), _ApprovalsTab()]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showApplyDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Apply'),
        ),
      ),
    );
  }
}

class _MyRequestsTab extends ConsumerWidget {
  const _MyRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(_myLeaveRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_myLeaveRequestsProvider),
      child: requests.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No leave requests yet',
                subtitle: 'Tap Apply to request time off',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final typeName = (r['leave_types'] as Map?)?['name'] ?? 'Leave';
                  final status = r['status'] as String;
                  final from = DateTime.parse(r['from_date'] as String);
                  final to = DateTime.parse(r['to_date'] as String);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _leaveStatusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.beach_access, color: _leaveStatusColor(status), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(typeName, style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  '${Formatters.date(from)} → ${Formatters.date(to)} · ${r['total_days']} day(s)',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          StatusPill(label: status, color: _leaveStatusColor(status), icon: _leaveStatusIcon(status)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ApprovalsTab extends ConsumerWidget {
  const _ApprovalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(teamLeaveRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(teamLeaveRequestsProvider),
      child: pending.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (rows) => rows.isEmpty
            ? const EmptyState(icon: Icons.task_alt_rounded, title: 'All caught up', subtitle: 'No pending requests')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final employee = r['employees'] as Map?;
                  final name = employee == null ? 'Employee' : '${employee['first_name']} ${employee['last_name']}';
                  final typeName = (r['leave_types'] as Map?)?['name'] ?? 'Leave';
                  final reason = r['reason'] as String?;
                  final from = DateTime.parse(r['from_date'] as String);
                  final to = DateTime.parse(r['to_date'] as String);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                                    Text(
                                      '$typeName · ${Formatters.date(from)} → ${Formatters.date(to)} (${r['total_days']}d)',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (reason != null && reason.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(reason, style: Theme.of(context).textTheme.bodySmall),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Reject'),
                                  onPressed: () async {
                                    final me = await ref.read(currentEmployeeProvider.future);
                                    if (me == null) return;
                                    await ref.read(leaveApprovalActionsProvider).decide(r['id'] as String, approve: false, approverId: me.id);
                                    ref.invalidate(teamLeaveRequestsProvider);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Approve'),
                                  onPressed: () async {
                                    final me = await ref.read(currentEmployeeProvider.future);
                                    if (me == null) return;
                                    await ref.read(leaveApprovalActionsProvider).decide(r['id'] as String, approve: true, approverId: me.id);
                                    ref.invalidate(teamLeaveRequestsProvider);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
