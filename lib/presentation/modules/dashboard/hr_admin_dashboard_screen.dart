import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../shared/widgets/kpi_card.dart';
import '../../shared/widgets/notification_bell_button.dart';
import '../employees/employee_form_screen.dart';
import '../payroll/payroll_admin_screen.dart';
import '../../../core/utils/error_helper.dart';

final _orgStatsProvider = FutureProvider.autoDispose((ref) async {
  final client = SupabaseService.client;
  final today = DateTime.now().toIso8601String().split('T').first;

  final totalEmployees = await client.from(Tables.employees).count().eq('status', 'active');
  final presentToday = await client.from(Tables.attendance).count().eq('date', today).eq('status', 'present');
  final onLeaveToday = await client
      .from(Tables.leaveRequests)
      .count()
      .eq('status', 'approved')
      .lte('from_date', today)
      .gte('to_date', today);

  return (totalEmployees: totalEmployees, presentToday: presentToday, onLeaveToday: onLeaveToday);
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

class HrAdminDashboardScreen extends ConsumerWidget {
  const HrAdminDashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final orgStats = ref.watch(_orgStatsProvider);
    final pendingApprovals = ref.watch(orgPendingApprovalsCountProvider);
    final payrollAwaiting = ref.watch(payrollRunsAwaitingProvider);
    final departments = ref.watch(departmentHeadcountProvider);
    final recentHires = ref.watch(recentHiresProvider);
    final nextEvent = ref.watch(_nextEventProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_orgStatsProvider);
          ref.invalidate(orgPendingApprovalsCountProvider);
          ref.invalidate(payrollRunsAwaitingProvider);
          ref.invalidate(departmentHeadcountProvider);
          ref.invalidate(recentHiresProvider);
          ref.invalidate(_nextEventProvider);
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
                  Row(
                    children: [
                      Text(Formatters.date(DateTime.now()), style: textTheme.bodyMedium),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                        child: Text('HR / Admin view', style: TextStyle(color: colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Org KPI grid
                  orgStats.when(
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('Could not load stats: ${friendlyError(e)}', style: TextStyle(color: colorScheme.error)),
                    data: (s) => GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        KpiCard(label: 'Total Employees', value: '${s.totalEmployees}', icon: Icons.people_alt_rounded, color: colorScheme.primary),
                        KpiCard(label: 'Present Today', value: '${s.presentToday}', icon: Icons.check_circle_rounded, color: Colors.green),
                        KpiCard(label: 'On Leave', value: '${s.onLeaveToday}', icon: Icons.beach_access_rounded, color: Colors.orange),
                        pendingApprovals.when(
                          loading: () => const KpiCard(label: 'Pending Approvals', value: '…', icon: Icons.fact_check_outlined, color: Colors.indigo),
                          error: (_, __) => const KpiCard(label: 'Pending Approvals', value: '-', icon: Icons.fact_check_outlined, color: Colors.indigo),
                          data: (count) => KpiCard(label: 'Pending Approvals', value: '$count', icon: Icons.fact_check_outlined, color: Colors.indigo),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text('Quick actions', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 92,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'Add Employee', color: colorScheme.primary, onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeFormScreen()));
                        }),
                        _QuickAction(icon: Icons.fact_check_outlined, label: 'Approvals', color: Colors.indigo, onTap: () => context.go('/leave')),
                        _QuickAction(icon: Icons.admin_panel_settings_outlined, label: 'Payroll Admin', color: Colors.brown, onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollAdminScreen()));
                        }),
                        _QuickAction(icon: Icons.people_outline, label: 'Directory', color: Colors.teal, onTap: () => context.go('/employees')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  payrollAwaiting.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (count) => count == 0
                        ? const SizedBox.shrink()
                        : Card(
                            color: Colors.orange.withOpacity(0.08),
                            child: ListTile(
                              leading: const Icon(Icons.payments_outlined, color: Colors.orange),
                              title: Text('$count payroll run${count == 1 ? '' : 's'} need attention', style: textTheme.titleSmall),
                              subtitle: const Text('Draft or processing runs waiting to be finished'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollAdminScreen())),
                            ),
                          ),
                  ),

                  const SizedBox(height: 12),
                  Text('Headcount by department', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  departments.when(
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LinearProgressIndicator()),
                    error: (e, _) => Text('Could not load: ${friendlyError(e)}'),
                    data: (rows) => rows.isEmpty
                        ? Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('No department data yet', style: textTheme.bodySmall)))
                        : Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                children: [
                                  for (final d in rows) ...[
                                    _DepartmentRow(name: d['name'] as String, count: d['count'] as int, maxCount: rows.first['count'] as int),
                                    if (d != rows.last) const Divider(height: 1),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),
                  Text('Recent hires', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  recentHires.when(
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LinearProgressIndicator()),
                    error: (e, _) => Text('Could not load: ${friendlyError(e)}'),
                    data: (rows) => rows.isEmpty
                        ? Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('No new hires in the last 30 days', style: textTheme.bodySmall)))
                        : Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (final e in rows)
                                  ListTile(
                                    onTap: () => context.push('/employees/${e['id']}'),
                                    leading: CircleAvatar(child: Text((e['first_name'] as String).substring(0, 1).toUpperCase())),
                                    title: Text('${e['first_name']} ${e['last_name']}'),
                                    subtitle: Text(e['designation'] as String? ?? 'Employee'),
                                    trailing: Text(Formatters.date(DateTime.parse(e['join_date'] as String)), style: textTheme.bodySmall),
                                  ),
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),
                  Text('Coming up', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  nextEvent.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (event) {
                      if (event == null) {
                        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('No upcoming events', style: textTheme.bodyMedium)));
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

class _DepartmentRow extends StatelessWidget {
  final String name;
  final int count;
  final int maxCount;
  const _DepartmentRow({required this.name, required this.count, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: Theme.of(context).textTheme.bodyMedium),
              Text('$count', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
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
