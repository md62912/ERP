import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/attendance_rules.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/async_states.dart';

/// Attendance for a specific (year, month) for the signed-in employee,
/// keyed by day-of-month for quick calendar lookup.
final _monthAttendanceProvider = FutureProvider.autoDispose
    .family<Map<int, Map<String, dynamic>>, ({int year, int month})>((ref, period) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return {};
  final first = DateTime(period.year, period.month, 1);
  final last = DateTime(period.year, period.month + 1, 0);
  final rows = await SupabaseService.client
      .from(Tables.attendance)
      .select()
      .eq('employee_id', me.id)
      .gte('date', first.toIso8601String().split('T').first)
      .lte('date', last.toIso8601String().split('T').first);
  final map = <int, Map<String, dynamic>>{};
  for (final r in (rows as List).cast<Map<String, dynamic>>()) {
    final d = DateTime.parse(r['date'] as String);
    map[d.day] = r;
  }
  return map;
});

class AttendanceCalendar extends ConsumerStatefulWidget {
  const AttendanceCalendar({super.key});

  @override
  ConsumerState<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends ConsumerState<AttendanceCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  void _shiftMonth(int delta) {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1));
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final period = (year: _visibleMonth.year, month: _visibleMonth.month);
    final monthData = ref.watch(_monthAttendanceProvider(period));
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // weekday of the 1st (Mon=1..Sun=7); we render weeks starting Monday.
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday;
    final leadingBlanks = firstWeekday - 1;
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_monthAttendanceProvider(period)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
              Text('${_monthNames[_visibleMonth.month]} ${_visibleMonth.year}',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                onPressed: (_visibleMonth.year == now.year && _visibleMonth.month == now.month)
                    ? null
                    : () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Weekday headers (Mon-Sun)
          Row(
            children: [
              for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                Expanded(
                  child: Center(
                    child: Text(d, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          monthData.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView()),
            error: (e, _) => ErrorView(error: e),
            data: (byDay) => GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  _DayCell(
                    day: day,
                    row: byDay[day],
                    isToday: now.year == _visibleMonth.year && now.month == _visibleMonth.month && now.day == day,
                    isFuture: DateTime(_visibleMonth.year, _visibleMonth.month, day).isAfter(DateTime(now.year, now.month, now.day)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _MonthSummary(period: period),
          const SizedBox(height: 16),
          _Legend(),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final Map<String, dynamic>? row;
  final bool isToday;
  final bool isFuture;
  const _DayCell({required this.day, required this.row, required this.isToday, required this.isFuture});

  @override
  Widget build(BuildContext context) {
    final status = row?['status'] as String?;
    final hasData = status != null;
    final color = hasData ? AttendanceRules.color(status) : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        color: hasData ? color.withOpacity(0.16) : (isFuture ? null : Colors.grey.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isFuture ? Colors.grey : (hasData ? color : null),
              ),
            ),
            if (hasData)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthSummary extends ConsumerWidget {
  final ({int year, int month}) period;
  const _MonthSummary({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthData = ref.watch(_monthAttendanceProvider(period));
    return monthData.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (byDay) {
        var present = 0, late = 0, half = 0, absent = 0;
        double totalHours = 0;
        for (final r in byDay.values) {
          switch (r['status'] as String?) {
            case 'present':
              present++;
              break;
            case 'late':
              late++;
              break;
            case 'half_day':
              half++;
              break;
            case 'absent':
              absent++;
              break;
          }
          totalHours += (r['work_hours'] as num?)?.toDouble() ?? 0;
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This month', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _SummaryStat(label: 'Present', value: '$present', color: Colors.green),
                    _SummaryStat(label: 'Late', value: '$late', color: Colors.orange),
                    _SummaryStat(label: 'Half days', value: '$half', color: Colors.amber),
                    _SummaryStat(label: 'Absent', value: '$absent', color: Colors.red),
                    _SummaryStat(label: 'Total hours', value: '${totalHours.toStringAsFixed(1)}h', color: Colors.indigo),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget dot(String status) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: AttendanceRules.color(status), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(AttendanceRules.label(status), style: Theme.of(context).textTheme.bodySmall),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [dot('present'), dot('late'), dot('half_day'), dot('absent')],
    );
  }
}
