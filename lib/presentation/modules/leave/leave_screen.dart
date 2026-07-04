import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_approval_provider.dart';
import '../../../domain/entities/employee.dart';

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
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => range = picked);
                },
                child: Text(range == null
                    ? 'Select dates'
                    : '${range!.start.toIso8601String().split('T').first} → ${range!.end.toIso8601String().split('T').first}'),
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
      // Employees just see their own requests — no need for tabs.
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
        body: const TabBarView(
          children: [_MyRequestsTab(), _ApprovalsTab()],
        ),
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

    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load requests: $e')),
      data: (rows) => rows.isEmpty
          ? const Center(child: Text('No leave requests yet'))
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final typeName = (r['leave_types'] as Map?)?['name'] ?? 'Leave';
                return ListTile(
                  title: Text('$typeName · ${r['total_days']} day(s)'),
                  subtitle: Text('${r['from_date']} → ${r['to_date']}'),
                  trailing: Chip(label: Text(r['status'] as String)),
                );
              },
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load approvals: $e')),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No pending requests'))
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final employee = r['employees'] as Map?;
                  final name = employee == null
                      ? 'Employee'
                      : '${employee['first_name']} ${employee['last_name']}';
                  final typeName = (r['leave_types'] as Map?)?['name'] ?? 'Leave';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text('$typeName · ${r['from_date']} → ${r['to_date']} (${r['total_days']}d)'
                          '${r['reason'] != null && (r['reason'] as String).isNotEmpty ? '\n${r['reason']}' : ''}'),
                      isThreeLine: r['reason'] != null && (r['reason'] as String).isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            tooltip: 'Approve',
                            onPressed: () async {
                              final me = await ref.read(currentEmployeeProvider.future);
                              if (me == null) return;
                              await ref
                                  .read(leaveApprovalActionsProvider)
                                  .decide(r['id'] as String, approve: true, approverId: me.id);
                              ref.invalidate(teamLeaveRequestsProvider);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: 'Reject',
                            onPressed: () async {
                              final me = await ref.read(currentEmployeeProvider.future);
                              if (me == null) return;
                              await ref
                                  .read(leaveApprovalActionsProvider)
                                  .decide(r['id'] as String, approve: false, approverId: me.id);
                              ref.invalidate(teamLeaveRequestsProvider);
                            },
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
