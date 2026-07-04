import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

/// Whether the signed-in employee has anyone reporting to them --
/// independent of their system `role`. This is what actually determines
/// whether someone can approve leave (Postgres RLS keys off `manager_id`,
/// not off role='manager'), so a Site Engineer with role 'employee' who
/// supervises Technicians still needs to see the Approvals tab.
final hasDirectReportsProvider = FutureProvider.autoDispose<bool>((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return false;
  final count = await SupabaseService.client.from(Tables.employees).count().eq('manager_id', me.id);
  return count > 0;
});

/// Pending leave requests visible to the signed-in manager/hr/admin.
/// RLS already scopes this correctly: managers see their direct reports'
/// requests, hr/admin see everyone's — this query just asks for "pending"
/// and lets Postgres filter by who's allowed to see what.
final teamLeaveRequestsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(Tables.leaveRequests)
      .select('*, leave_types(name), employees!leave_requests_employee_id_fkey(first_name, last_name)')
      .eq('status', 'pending')
      .order('applied_at');
  return (rows as List).cast<Map<String, dynamic>>();
});

final leaveApprovalActionsProvider = Provider((ref) => LeaveApprovalActions());

class LeaveApprovalActions {
  Future<void> decide(String requestId, {required bool approve, required String approverId}) async {
    final row = await SupabaseService.client
        .from(Tables.leaveRequests)
        .update({
          'status': approve ? 'approved' : 'rejected',
          'approved_by': approverId,
        })
        .eq('id', requestId)
        .select('employee_id')
        .single();

    try {
      await NotificationActions().notify(
        employeeId: row['employee_id'] as String,
        title: approve ? 'Leave request approved' : 'Leave request rejected',
        body: approve ? 'Your leave request has been approved.' : 'Your leave request was not approved.',
      );
    } catch (_) {
      // Notification is a nice-to-have -- don't fail the approval itself
      // if, for whatever reason, the notification insert doesn't go through.
    }
  }
}
