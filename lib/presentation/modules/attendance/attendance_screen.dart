import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/attendance_rules.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import 'attendance_admin_screen.dart';
import 'attendance_calendar.dart';

final _myAttendanceProvider = FutureProvider.autoDispose((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return <Map<String, dynamic>>[];
  final rows = await SupabaseService.client
      .from(Tables.attendance)
      .select()
      .eq('employee_id', me.id)
      .order('date', ascending: false)
      .limit(30);
  return (rows as List).cast<Map<String, dynamic>>();
});

final _todayStatusProvider = FutureProvider.autoDispose((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return null;
  final today = DateTime.now().toIso8601String().split('T').first;
  final rows = await SupabaseService.client
      .from(Tables.attendance)
      .select()
      .eq('employee_id', me.id)
      .eq('date', today)
      .limit(1);
  final list = rows as List;
  return list.isEmpty ? null : list.first as Map<String, dynamic>;
});

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    final me = await ref.read(currentEmployeeProvider.future);
    if (me == null) {
      notifyProfileNotReady(context);
      return;
    }
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    // Status is derived by the rules engine (late vs present) rather than
    // hardcoded, based on whether the check-in beat the lateness cutoff.
    final status = AttendanceRules.deriveStatus(checkIn: now, checkOut: null);
    await SupabaseService.client.from(Tables.attendance).upsert({
      'employee_id': me.id,
      'date': today,
      'check_in': now.toIso8601String(),
      'status': status,
    }, onConflict: 'employee_id,date');
    ref.invalidate(_myAttendanceProvider);
    ref.invalidate(_todayStatusProvider);
  }

  Future<void> _checkOut(BuildContext context, WidgetRef ref) async {
    final me = await ref.read(currentEmployeeProvider.future);
    if (me == null) {
      notifyProfileNotReady(context);
      return;
    }
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;

    // Re-read today's check-in so we can compute final work_hours and a
    // status that accounts for the full day (e.g. half-day if short).
    final existing = await SupabaseService.client
        .from(Tables.attendance)
        .select('check_in')
        .eq('employee_id', me.id)
        .eq('date', today)
        .maybeSingle();

    DateTime? checkIn;
    if (existing != null && existing['check_in'] != null) {
      checkIn = DateTime.parse(existing['check_in'] as String);
    }
    final hours = AttendanceRules.workHours(checkIn: checkIn, checkOut: now);
    final status = AttendanceRules.deriveStatus(checkIn: checkIn, checkOut: now);

    await SupabaseService.client
        .from(Tables.attendance)
        .update({
          'check_out': now.toIso8601String(),
          'work_hours': hours,
          'status': status,
        })
        .eq('employee_id', me.id)
        .eq('date', today);
    ref.invalidate(_myAttendanceProvider);
    ref.invalidate(_todayStatusProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_myAttendanceProvider);
    final todayStatus = ref.watch(_todayStatusProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          actions: [
            Consumer(
              builder: (context, ref, _) {
                final role = ref.watch(currentUserRoleProvider);
                if (role == UserRole.admin || role == UserRole.hr) {
                  return IconButton(
                    icon: const Icon(Icons.groups_outlined),
                    tooltip: 'Team attendance',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AttendanceAdminScreen()),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Today'), Tab(text: 'Calendar')]),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_myAttendanceProvider);
          ref.invalidate(_todayStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Today status card
            todayStatus.when(
              loading: () => const SizedBox(height: 120, child: LoadingView()),
              error: (e, _) => ErrorView(error: e),
              data: (row) {
                final checkedIn = row?['check_in'] != null;
                final checkedOut = row?['check_out'] != null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Today', style: Theme.of(context).textTheme.titleMedium),
                            StatusPill(
                              label: checkedOut ? 'Done' : (checkedIn ? 'Checked in' : 'Not started'),
                              color: checkedOut ? Colors.blueGrey : (checkedIn ? Colors.green : colorScheme.primary),
                              icon: checkedOut
                                  ? Icons.check_circle
                                  : (checkedIn ? Icons.timer : Icons.schedule),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(Formatters.date(DateTime.now()), style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _TimeBlock(
                                label: 'Check In',
                                time: row?['check_in'] != null ? Formatters.time(DateTime.parse(row!['check_in'])) : '--:--',
                                icon: Icons.login_rounded,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimeBlock(
                                label: 'Check Out',
                                time: row?['check_out'] != null ? Formatters.time(DateTime.parse(row!['check_out'])) : '--:--',
                                icon: Icons.logout_rounded,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final ci = row?['check_in'] != null ? DateTime.parse(row!['check_in']) : null;
                            final co = row?['check_out'] != null ? DateTime.parse(row!['check_out']) : null;
                            final worked = AttendanceRules.workHours(checkIn: ci, checkOut: co);
                            final ot = AttendanceRules.overtimeHours(checkIn: ci, checkOut: co);
                            final late = ci != null && AttendanceRules.isLate(ci);
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (worked > 0)
                                  StatusPill(label: '${worked}h worked', color: Colors.indigo, icon: Icons.timelapse),
                                if (ot > 0)
                                  StatusPill(label: '${ot}h overtime', color: Colors.deepPurple, icon: Icons.more_time),
                                if (late)
                                  StatusPill(label: 'Late arrival', color: Colors.orange, icon: Icons.running_with_errors),
                                if (ci == null)
                                  StatusPill(
                                    label: 'Starts ${AttendanceRules.workStartHour.toString().padLeft(2, '0')}:${AttendanceRules.workStartMinute.toString().padLeft(2, '0')}',
                                    color: Colors.blueGrey,
                                    icon: Icons.schedule,
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: checkedIn ? null : () => _checkIn(context, ref),
                                icon: const Icon(Icons.login, size: 18),
                                label: const Text('Check In'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: (!checkedIn || checkedOut) ? null : () => _checkOut(context, ref),
                                icon: const Icon(Icons.logout, size: 18),
                                label: const Text('Check Out'),
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

            const SizedBox(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            history.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView()),
              error: (e, _) => ErrorView(error: e),
              data: (rows) => rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: EmptyState(icon: Icons.fingerprint, title: 'No attendance history yet'),
                    )
                  : Column(
                      children: [
                        for (final r in rows) _AttendanceRow(row: r),
                      ],
                    ),
            ),
          ],
        ),
            ),
            const AttendanceCalendar(),
          ],
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;

  const _TimeBlock({required this.label, required this.time, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(time, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _AttendanceRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(row['date'] as String);
    final status = row['status'] as String? ?? 'present';
    final workHours = (row['work_hours'] as num?)?.toDouble();
    final color = AttendanceRules.color(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.14),
          child: Text('${date.day}', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ),
        title: Text(Formatters.date(date)),
        subtitle: Text(
          'In: ${row['check_in'] != null ? Formatters.time(DateTime.parse(row['check_in'])) : '-'}   '
          'Out: ${row['check_out'] != null ? Formatters.time(DateTime.parse(row['check_out'])) : '-'}'
          '${workHours != null && workHours > 0 ? '   ·   ${workHours}h' : ''}',
        ),
        trailing: StatusPill(label: AttendanceRules.label(status), color: color),
      ),
    );
  }
}
