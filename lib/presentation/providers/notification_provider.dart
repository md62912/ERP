import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';
import 'auth_provider.dart';

/// Live stream of the signed-in employee's notifications, newest first.
/// Uses Supabase Realtime (`.stream()`) rather than a one-shot fetch, so
/// a new row appearing (e.g. a leave approval) shows up immediately
/// while the app is open -- no manual refresh needed. This only works
/// while the app process is alive (foreground or backgrounded); it is
/// not equivalent to OS-level push notifications, which would require
/// Firebase Cloud Messaging and a Firebase project.
final myNotificationsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) {
    yield [];
    return;
  }
  yield* SupabaseService.client
      .from(Tables.notifications)
      .stream(primaryKey: ['id'])
      .eq('employee_id', me.id)
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(myNotificationsProvider).valueOrNull ?? [];
  return notifications.where((n) => n['is_read'] != true).length;
});

final notificationActionsProvider = Provider((ref) => NotificationActions());

class NotificationActions {
  Future<void> markRead(String notificationId) async {
    await SupabaseService.client.from(Tables.notifications).update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllRead(String employeeId) async {
    await SupabaseService.client
        .from(Tables.notifications)
        .update({'is_read': true})
        .eq('employee_id', employeeId)
        .eq('is_read', false);
  }

  /// Used by other actions (leave approval, task assignment, event
  /// invites) to notify the affected employee. Not exposed to RLS
  /// concerns beyond the existing `notifications_system_insert` policy,
  /// which already permits admin/hr/manager to insert -- callers outside
  /// that role will simply have the insert silently rejected by RLS,
  /// so wrap calls to this in a try/catch if the caller isn't guaranteed
  /// to hold one of those roles.
  Future<void> notify({
    required String employeeId,
    required String title,
    String? body,
    String? link,
  }) async {
    await SupabaseService.client.from(Tables.notifications).insert({
      'employee_id': employeeId,
      'title': title,
      'body': body,
      'link': link,
    });
  }
}
