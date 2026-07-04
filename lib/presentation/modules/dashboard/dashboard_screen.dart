import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/kpi_card.dart';

final _dashboardStatsProvider = FutureProvider.autoDispose((ref) async {
  final client = SupabaseService.client;
  final today = DateTime.now().toIso8601String().split('T').first;

  final totalEmployees = await client.from(Tables.employees).count().eq('status', 'active');

  final presentToday = await client
      .from(Tables.attendance)
      .count()
      .eq('date', today)
      .eq('status', 'present');

  final onLeaveToday = await client
      .from(Tables.leaveRequests)
      .count()
      .eq('status', 'approved')
      .lte('from_date', today)
      .gte('to_date', today);

  final payrollDue = await client
      .from(Tables.payrollRuns)
      .count()
      .inFilter('status', ['draft', 'processing']);

  return (
    totalEmployees: totalEmployees,
    presentToday: presentToday,
    onLeaveToday: onLeaveToday,
    payrollDue: payrollDue,
  );
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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_dashboardStatsProvider);
    final nextEvent = ref.watch(_nextEventProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_dashboardStatsProvider);
          ref.invalidate(_nextEventProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 20,
              title: Text(
                me == null ? _greeting() : '${_greeting()}, ${me.firstName}',
                style: textTheme.titleLarge,
              ),
              actions: [
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
                  Text(Formatters.date(DateTime.now()), style: textTheme.bodyMedium),
                  const SizedBox(height: 20),

                  // KPI grid
                  stats.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Could not load stats: $e', style: TextStyle(color: colorScheme.error)),
                    ),
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
                        KpiCard(label: 'Payroll Due', value: '${s.payrollDue}', icon: Icons.payments_rounded, color: Colors.purple),
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
                        _QuickAction(icon: Icons.fingerprint, label: 'Check In', color: colorScheme.primary, onTap: () => context.go('/attendance')),
                        _QuickAction(icon: Icons.beach_access_outlined, label: 'Apply Leave', color: Colors.orange, onTap: () => context.go('/leave')),
                        _QuickAction(icon: Icons.receipt_long_outlined, label: 'Payslips', color: Colors.purple, onTap: () => context.go('/payroll')),
                        _QuickAction(icon: Icons.people_outline, label: 'Directory', color: Colors.teal, onTap: () => context.go('/employees')),
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
