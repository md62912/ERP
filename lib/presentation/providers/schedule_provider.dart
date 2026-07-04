import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';
import '../../domain/entities/project.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

/// Events either created by me or where I'm an invited attendee, from
/// today onward — a simple upcoming-agenda view.
final myUpcomingEventsProvider = FutureProvider.autoDispose<List<ScheduleEvent>>((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return [];

  final rows = await SupabaseService.client
      .from(Tables.scheduleEvents)
      .select('*, schedule_attendees!inner(employee_id)')
      .or('created_by.eq.${me.id},schedule_attendees.employee_id.eq.${me.id}')
      .gte('end_time', DateTime.now().toIso8601String())
      .order('start_time');

  // dedupe (a creator who's also an attendee could appear twice)
  final seen = <String>{};
  final events = <ScheduleEvent>[];
  for (final row in rows as List) {
    final map = row as Map<String, dynamic>;
    if (seen.add(map['id'] as String)) {
      events.add(ScheduleEvent.fromJson(map));
    }
  }
  return events;
});

/// Attendee list for one event, joined with employee names, for display
/// on the event card and the create/invite dialog.
final eventAttendeesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final rows = await SupabaseService.client
      .from(Tables.scheduleAttendees)
      .select('*, employees(first_name, last_name)')
      .eq('schedule_event_id', eventId);
  return (rows as List).cast<Map<String, dynamic>>();
});

final scheduleActionsProvider = Provider((ref) => ScheduleActions());

class ScheduleActions {
  Future<void> createEvent(ScheduleEvent event, {List<String> attendeeIds = const []}) async {
    final created = await SupabaseService.client
        .from(Tables.scheduleEvents)
        .insert(event.toInsertJson())
        .select()
        .single();
    final eventId = created['id'] as String;
    if (attendeeIds.isNotEmpty) {
      await SupabaseService.client.from(Tables.scheduleAttendees).insert([
        for (final id in attendeeIds) {'schedule_event_id': eventId, 'employee_id': id},
      ]);

      try {
        for (final id in attendeeIds) {
          await NotificationActions().notify(
            employeeId: id,
            title: 'Event invite: ${event.title}',
            body: 'You\'ve been invited to an event.',
          );
        }
      } catch (_) {
        // Non-critical -- the event and invites themselves were already created.
      }
    }
  }

  Future<void> respond(String eventId, String employeeId, String response) async {
    await SupabaseService.client
        .from(Tables.scheduleAttendees)
        .update({'response': response})
        .eq('schedule_event_id', eventId)
        .eq('employee_id', employeeId);
  }
}
