import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';
import '../../domain/entities/employee.dart';
import 'auth_provider.dart';

// ---- Employee dashboard ----

/// My leave balances for the current year, one row per leave type with
/// allocated/used/remaining.
final myLeaveBalancesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return [];
  final year = DateTime.now().year;
  final rows = await SupabaseService.client
      .from(Tables.leaveBalances)
      .select('*, leave_types(name)')
      .eq('employee_id', me.id)
      .eq('year', year);
  return (rows as List).cast<Map<String, dynamic>>();
});

/// Count of my tasks that aren't done yet, across every project.
final myPendingTaskCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return 0;
  return SupabaseService.client
      .from(Tables.tasks)
      .count()
      .eq('assignee_id', me.id)
      .neq('status', 'done');
});

/// My single most recent payslip, for a quick "last pay" summary card.
final myLatestPayslipProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return null;
  final rows = await SupabaseService.client
      .from(Tables.payslips)
      .select('*, payroll_runs(month, year)')
      .eq('employee_id', me.id)
      .order('created_at', ascending: false)
      .limit(1);
  final list = rows as List;
  return list.isEmpty ? null : list.first as Map<String, dynamic>;
});

/// For managers: how many of their team's leave requests are pending —
/// shown as a shortcut card on the employee-style dashboard rather than
/// building a third dashboard variant just for managers.
final myTeamPendingApprovalsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final role = ref.watch(currentUserRoleProvider);
  if (role != UserRole.manager) return 0;
  return SupabaseService.client.from(Tables.leaveRequests).count().eq('status', 'pending');
});

// ---- HR/Admin dashboard ----

/// Org-wide pending leave requests (RLS already limits this to what an
/// hr/admin account can see, which is everyone's).
final orgPendingApprovalsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return SupabaseService.client.from(Tables.leaveRequests).count().eq('status', 'pending');
});

/// Headcount grouped by department, for a quick org-shape overview.
final departmentHeadcountProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(Tables.employees)
      .select('department_id, departments(name)')
      .eq('status', 'active');

  final counts = <String, int>{};
  for (final r in rows as List) {
    final deptName = (r['departments'] as Map?)?['name'] as String? ?? 'Unassigned';
    counts[deptName] = (counts[deptName] ?? 0) + 1;
  }
  final result = [
    for (final entry in counts.entries) {'name': entry.key, 'count': entry.value},
  ];
  result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return result;
});

/// Employees who joined in the last 30 days.
final recentHiresProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T').first;
  final rows = await SupabaseService.client
      .from(Tables.employees)
      .select()
      .gte('join_date', since)
      .order('join_date', ascending: false)
      .limit(5);
  return (rows as List).cast<Map<String, dynamic>>();
});

/// Payroll runs still in draft or processing -- i.e. need attention.
final payrollRunsAwaitingProvider = FutureProvider.autoDispose<int>((ref) async {
  return SupabaseService.client.from(Tables.payrollRuns).count().inFilter('status', ['draft', 'processing']);
});
