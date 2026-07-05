import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/attendance_rules.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/attendance_export.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';

/// Every active employee (id + name + designation), for building the roster
/// (so people with NO attendance row for a day still appear, as absent).
final _allEmployeesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(Tables.employees)
      .select('id, first_name, last_name, designation')
      .eq('status', 'active')
      .order('first_name');
  return (rows as List).cast<Map<String, dynamic>>();
});

/// Attendance rows for a specific date across the whole org (admin/hr only;
/// RLS permits the read).
final _rosterForDateProvider =
    FutureProvider.autoDispose.family<Map<String, Map<String, dynamic>>, DateTime>((ref, date) async {
  final iso = date.toIso8601String().split('T').first;
  final rows = await SupabaseService.client.from(Tables.attendance).select().eq('date', iso);
  final byEmployee = <String, Map<String, dynamic>>{};
  for (final r in (rows as List).cast<Map<String, dynamic>>()) {
    byEmployee[r['employee_id'] as String] = r;
  }
  return byEmployee;
});

class AttendanceAdminScreen extends ConsumerStatefulWidget {
  const AttendanceAdminScreen({super.key});

  @override
  ConsumerState<AttendanceAdminScreen> createState() => _AttendanceAdminScreenState();
}

class _AttendanceAdminScreenState extends ConsumerState<AttendanceAdminScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _exporting = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final employees = await ref.read(_allEmployeesProvider.future);
      final roster = await ref.read(_rosterForDateProvider(_selectedDate).future);
      await exportAttendanceCsv(
        date: _selectedDate,
        employees: employees,
        roster: roster,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(_allEmployeesProvider);
    final roster = ref.watch(_rosterForDateProvider(_selectedDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Attendance'),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Export CSV',
                  onPressed: _export,
                ),
        ],
      ),
      body: Column(
        children: [
          // Date selector bar
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: InkWell(
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(Formatters.date(_selectedDate), style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    const Text('Change'),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: employees.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(error: e),
              data: (empList) => roster.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(error: e),
                data: (rosterMap) {
                  if (empList.isEmpty) {
                    return const EmptyState(icon: Icons.people_outline, title: 'No employees yet');
                  }
                  // Summary counts across the roster.
                  var present = 0, late = 0, absent = 0, half = 0;
                  for (final e in empList) {
                    final r = rosterMap[e['id']];
                    final status = r?['status'] as String? ?? 'absent';
                    switch (status) {
                      case 'present':
                        present++;
                        break;
                      case 'late':
                        late++;
                        break;
                      case 'half_day':
                        half++;
                        break;
                      default:
                        absent++;
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary strip
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _Stat(label: 'Present', value: '$present', color: Colors.green),
                              _Stat(label: 'Late', value: '$late', color: Colors.orange),
                              _Stat(label: 'Half day', value: '$half', color: Colors.amber),
                              _Stat(label: 'Absent', value: '$absent', color: Colors.red),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Roster', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final e in empList)
                        _RosterRow(employee: e, row: rosterMap[e['id']]),
                    ],
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RosterRow extends StatelessWidget {
  final Map<String, dynamic> employee;
  final Map<String, dynamic>? row;
  const _RosterRow({required this.employee, required this.row});

  @override
  Widget build(BuildContext context) {
    final name = '${employee['first_name']} ${employee['last_name']}';
    final designation = employee['designation'] as String?;
    final status = row?['status'] as String? ?? 'absent';
    final color = AttendanceRules.color(status);
    final checkIn = row?['check_in'] != null ? Formatters.time(DateTime.parse(row!['check_in'])) : '-';
    final checkOut = row?['check_out'] != null ? Formatters.time(DateTime.parse(row!['check_out'])) : '-';
    final hours = (row?['work_hours'] as num?)?.toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.14),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ),
        title: Text(name),
        subtitle: Text(
          '${designation ?? ''}${designation != null ? ' · ' : ''}In: $checkIn  Out: $checkOut'
          '${hours != null && hours > 0 ? '  ·  ${hours}h' : ''}',
        ),
        trailing: StatusPill(label: AttendanceRules.label(status), color: color),
      ),
    );
  }
}
