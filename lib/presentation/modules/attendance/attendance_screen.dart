import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';

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

  Future<void> _checkIn(WidgetRef ref) async {
    final me = await ref.read(currentEmployeeProvider.future);
    if (me == null) return;
    final today = DateTime.now().toIso8601String().split('T').first;
    await SupabaseService.client.from(Tables.attendance).upsert({
      'employee_id': me.id,
      'date': today,
      'check_in': DateTime.now().toIso8601String(),
      'status': 'present',
    }, onConflict: 'employee_id,date');
    ref.invalidate(_myAttendanceProvider);
    ref.invalidate(_todayStatusProvider);
  }

  Future<void> _checkOut(WidgetRef ref) async {
    final me = await ref.read(currentEmployeeProvider.future);
    if (me == null) return;
    final today = DateTime.now().toIso8601String().split('T').first;
    await SupabaseService.client
        .from(Tables.attendance)
        .update({'check_out': DateTime.now().toIso8601String()})
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

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
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
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: checkedIn ? null : () => _checkIn(ref),
                                icon: const Icon(Icons.login, size: 18),
                                label: const Text('Check In'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: (!checkedIn || checkedOut) ? null : () => _checkOut(ref),
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

  Color _statusColor(String status) => switch (status) {
        'present' => Colors.green,
        'late' => Colors.orange,
        'absent' => Colors.red,
        'half_day' => Colors.amber,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(row['date'] as String);
    final status = row['status'] as String? ?? 'present';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withOpacity(0.14),
          child: Text('${date.day}', style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700)),
        ),
        title: Text(Formatters.date(date)),
        subtitle: Text(
          'In: ${row['check_in'] != null ? Formatters.time(DateTime.parse(row['check_in'])) : '-'}   '
          'Out: ${row['check_out'] != null ? Formatters.time(DateTime.parse(row['check_out'])) : '-'}',
        ),
        trailing: StatusPill(label: status.replaceAll('_', ' '), color: _statusColor(status)),
      ),
    );
  }
}
