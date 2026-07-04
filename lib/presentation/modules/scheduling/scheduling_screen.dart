import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/employee.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';

class SchedulingScreen extends ConsumerWidget {
  const SchedulingScreen({super.key});

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime? start;
    DateTime? end;
    String eventType = 'meeting';
    final selectedAttendees = <String>{};

    final employees = await ref.read(employeeListProvider.future);
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location (optional)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: eventType,
                  items: const [
                    DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                    DropdownMenuItem(value: 'shift', child: Text('Shift')),
                    DropdownMenuItem(value: 'deadline', child: Text('Deadline')),
                    DropdownMenuItem(value: 'reminder', child: Text('Reminder')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => eventType = v!),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (time == null) return;
                    setState(() {
                      start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      end ??= start!.add(const Duration(hours: 1));
                    });
                  },
                  child: Text(start == null ? 'Pick start time' : '${Formatters.date(start)} ${Formatters.time(start)}'),
                ),
                if (start != null)
                  OutlinedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(end ?? start!.add(const Duration(hours: 1))),
                      );
                      if (time == null) return;
                      setState(() {
                        end = DateTime(start!.year, start!.month, start!.day, time.hour, time.minute);
                      });
                    },
                    child: Text(end == null ? 'Pick end time' : Formatters.time(end)),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Invite attendees', style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final emp in employees)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: selectedAttendees.contains(emp.id),
                            title: Text(emp.fullName),
                            subtitle: Text(emp.designation ?? emp.role.name, style: Theme.of(context).textTheme.bodySmall),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                selectedAttendees.add(emp.id);
                              } else {
                                selectedAttendees.remove(emp.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (start == null || end == null || titleCtrl.text.trim().isEmpty)
                  ? null
                  : () async {
                      await ref.read(scheduleActionsProvider).createEvent(
                            ScheduleEvent(
                              id: '',
                              title: titleCtrl.text.trim(),
                              location: locationCtrl.text.isEmpty ? null : locationCtrl.text,
                              eventType: eventType,
                              startTime: start!,
                              endTime: end!,
                            ),
                            attendeeIds: selectedAttendees.toList(),
                          );
                      if (context.mounted) Navigator.pop(context);
                      ref.invalidate(myUpcomingEventsProvider);
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'meeting' => Icons.groups_outlined,
        'shift' => Icons.schedule,
        'deadline' => Icons.flag_outlined,
        'reminder' => Icons.notifications_outlined,
        _ => Icons.event_outlined,
      };

  Color _colorFor(String type) => switch (type) {
        'meeting' => Colors.blue,
        'shift' => Colors.teal,
        'deadline' => Colors.red,
        'reminder' => Colors.orange,
        _ => Colors.blueGrey,
      };

  Color _responseColor(String response) => switch (response) {
        'accepted' => Colors.green,
        'declined' => Colors.red,
        'tentative' => Colors.orange,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(myUpcomingEventsProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myUpcomingEventsProvider),
        child: events.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(error: e),
          data: (list) => list.isEmpty
              ? const EmptyState(icon: Icons.event_available_outlined, title: 'No upcoming events')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final color = _colorFor(e.eventType);
                    final isOrganizer = me != null && e.createdBy == me.id;
                    final attendees = ref.watch(eventAttendeesProvider(e.id));

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 52,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                    children: [
                                      Text(
                                        e.startTime.day.toString(),
                                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
                                      ),
                                      Text(
                                        Formatters.date(e.startTime).split(' ')[1].toUpperCase(),
                                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(_iconFor(e.eventType), size: 16, color: color),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(e.title, style: Theme.of(context).textTheme.titleSmall)),
                                          if (isOrganizer) const StatusPill(label: 'organizer', color: Colors.indigo),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('${Formatters.time(e.startTime)} – ${Formatters.time(e.endTime)}', style: Theme.of(context).textTheme.bodySmall),
                                      if (e.location != null) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.place_outlined, size: 13, color: Theme.of(context).textTheme.bodySmall?.color),
                                            const SizedBox(width: 4),
                                            Text(e.location!, style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            attendees.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (rows) {
                                if (rows.isEmpty) return const SizedBox.shrink();
                                Map<String, dynamic>? myRow;
                                if (me != null) {
                                  for (final r in rows) {
                                    if (r['employee_id'] == me.id) {
                                      myRow = r;
                                      break;
                                    }
                                  }
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(height: 1),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final a in rows)
                                            StatusPill(
                                              label: '${(a['employees'] as Map?)?['first_name'] ?? '?'} · ${a['response']}',
                                              color: _responseColor(a['response'] as String),
                                            ),
                                        ],
                                      ),
                                      if (myRow != null && myRow['response'] == 'pending' && !isOrganizer) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                                onPressed: () async {
                                                  await ref.read(scheduleActionsProvider).respond(e.id, me!.id, 'declined');
                                                  ref.invalidate(eventAttendeesProvider(e.id));
                                                },
                                                child: const Text('Decline'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                onPressed: () async {
                                                  await ref.read(scheduleActionsProvider).respond(e.id, me!.id, 'accepted');
                                                  ref.invalidate(eventAttendeesProvider(e.id));
                                                },
                                                child: const Text('Accept'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
