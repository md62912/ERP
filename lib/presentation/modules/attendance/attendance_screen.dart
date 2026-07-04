import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../providers/auth_provider.dart';

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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_myAttendanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _checkIn(ref),
                    icon: const Icon(Icons.login),
                    label: const Text('Check In'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _checkOut(ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Check Out'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load history: $e')),
              data: (rows) => ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  return ListTile(
                    title: Text(r['date'] as String),
                    subtitle: Text(
                      'In: ${r['check_in'] != null ? Formatters.time(DateTime.parse(r['check_in'])) : '-'}  '
                      'Out: ${r['check_out'] != null ? Formatters.time(DateTime.parse(r['check_out'])) : '-'}',
                    ),
                    trailing: Text(r['status'] as String? ?? ''),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
