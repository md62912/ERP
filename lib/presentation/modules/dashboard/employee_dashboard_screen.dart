import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../shared/widgets/kpi_card.dart';
import '../../shared/widgets/notification_bell_button.dart';

final _todayAttendanceProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
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

final _nextEventProvider = FutureProvider.autoDispose((ref) async {
  final rows = await SupabaseService.client
      .from(Tables.scheduleEvents)
      .select()
      .gte('start_time', DateTime.now().toIso8601String())
      .order('start_time')
      .limit(1);
  final list = rows as List;
  return list.isEmpty ? null : list.first as Map<String, dynamic>;
});

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final role = ref.watch(currentUserRoleProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final attendance = ref.watch(_todayAttendanceProvider);
    final leaveBalances = ref.watch(myLeaveBalancesProvider);
    final pendingTasks = ref.watch(myPendingTaskCountProvider);
    final latestPayslip = ref.watch(myLatestPayslipProvider);
    final nextEvent = ref.watch(_nextEventProvider);
    final teamApprovals = ref.watch(myTeamPendingApprovalsCountProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_todayAttendanceProvider);
          ref.invalidate(myLeaveBalancesProvider);
          ref.invalidate(myPendingTaskCountProvider);
          ref.invalidate(myLatestPayslipProvider);
          ref.invalidate(_nextEventProvider);
          ref.invalidate(myTeamPendingApprovalsCountProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 20,
              title: Text(me == null ? _greeting() : '${_greeting()}, ${me.firstName}', style: textTheme.titleLarge),
              actions: [
                const NotificationBellButton(),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Sign out',
                  onPressed: () => ref.read(authControllerProvider).signOut(),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (ref.watch(isShowingCachedDataProvider)) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You're offline — showing your last saved profile",
                              style: textTheme.bodySmall?.copyWith(color: Colors.orange[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(Formatters.date(DateTime.now()), style: textTheme.bodyMedium),
                  const SizedBox(height: 20),

                  // Today's attendance status card
                  attendance.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (row) {
                      final checkedIn = row?['check_in'] != null;
                      final checkedOut = row?['check_out'] != null;
                      final statusColor = checkedOut ? Colors.blueGrey : (checkedIn ? Colors.green : Colors.orange);
                      final statusLabel = checkedOut ? 'Day complete' : (checkedIn ? 'Checked in' : "You haven't checked in yet");
                      return Card(
                        child: ListTile(
                          onTap: () => context.go('/attendance'),
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.14),
                            child: Icon(Icons.fingerprint, color: statusColor),
                          ),
                          title: Text(statusLabel, style: textTheme.titleSmall),
                          subtitle: checkedIn
                              ? Text('In: ${Formatters.time(DateTime.parse(row!['check_in']))}'
                                  '${checkedOut ? '  ·  Out: ${Formatters.time(DateTime.parse(row['check_out']))}' : ''}')
                              : const Text('Tap to check in'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // KPI grid: leave balance, pending tasks, last payslip
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      leaveBalances.when(
                        loading: () => const KpiCard(label: 'Leave Remaining', value: '…', icon: Icons.beach_access_rounded, color: Colors.orange),
                        error: (_, __) => const KpiCard(label: 'Leave Remaining', value: '-', icon: Icons.beach_access_rounded, color: Colors.orange),
                        data: (rows) {
                          final remaining = rows.fold<double>(
                            0,
                            (sum, r) => sum + ((r['allocated_days'] as num? ?? 0) - (r['used_days'] as num? ?? 0)),
                          );
                          return KpiCard(label: 'Leave Remaining', value: '${remaining.round()}d', icon: Icons.beach_access_rounded, color: Colors.orange);
                        },
                      ),
                      pendingTasks.when(
                        loading: () => const KpiCard(label: 'Pending Tasks', value: '…', icon: Icons.task_alt_rounded, color: Colors.teal),
                        error: (_, __) => const KpiCard(label: 'Pending Tasks', value: '-', icon: Icons.task_alt_rounded, color: Colors.teal),
                        data: (count) => KpiCard(label: 'Pending Tasks', value: '$count', icon: Icons.task_alt_rounded, color: Colors.teal),
                      ),
                      latestPayslip.when(
                        loading: () => const KpiCard(label: 'Last Payslip', value: '…', icon: Icons.receipt_long_rounded, color: Colors.purple),
                        error: (_, __) => const KpiCard(label: 'Last Payslip', value: '-', icon: Icons.receipt_long_rounded, color: Colors.purple),
                        data: (row) => KpiCard(
                          label: 'Last Payslip',
                          value: row == null ? '-' : Formatters.currency(row['net_salary']),
                          icon: Icons.receipt_long_rounded,
                          color: Colors.purple,
                        ),
                      ),
                      if (role == UserRole.manager)
                        teamApprovals.when(
                          loading: () => const KpiCard(label: 'Team Approvals', value: '…', icon: Icons.fact_check_outlined, color: Colors.indigo),
                          error: (_, __) => const KpiCard(label: 'Team Approvals', value: '-', icon: Icons.fact_check_outlined, color: Colors.indigo),
                          data: (count) => KpiCard(label: 'Team Approvals', value: '$count', icon: Icons.fact_check_outlined, color: Colors.indigo),
                        ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  Text('Quick actions', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 92,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _QuickAction(icon: Icons.fingerprint, label: 'Check In', color: colorScheme.primary, onTap: () => context.go('/attendance')),
                        _QuickAction(icon: Icons.beach_access_outlined, label: 'Apply Leave', color: Colors.orange, onTap: () => context.go('/leave')),
                        _QuickAction(icon: Icons.receipt_long_outlined, label: 'Payslips', color: Colors.purple, onTap: () => context.go('/payroll')),
                        _QuickAction(icon: Icons.checklist_rounded, label: 'My Tasks', color: Colors.teal, onTap: () => context.push('/tasks')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text('Coming up', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  nextEvent.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (event) {
                      if (event == null) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No upcoming events', style: textTheme.bodyMedium),
                          ),
                        );
                      }
                      final start = DateTime.parse(event['start_time'] as String);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primary.withOpacity(0.14),
                            child: Icon(Icons.event_outlined, color: colorScheme.primary),
                          ),
                          title: Text(event['title'] as String),
                          subtitle: Text('${Formatters.date(start)} · ${Formatters.time(start)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/scheduling'),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
