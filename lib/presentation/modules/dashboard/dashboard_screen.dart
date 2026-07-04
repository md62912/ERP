import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/kpi_card.dart';

final _dashboardStatsProvider = FutureProvider.autoDispose((ref) async {
  final client = SupabaseService.client;
  final today = DateTime.now().toIso8601String().split('T').first;

  final totalEmployees = await client
      .from(Tables.employees)
      .count()
      .eq('status', 'active');

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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_dashboardStatsProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(me == null ? 'Dashboard' : 'Hi, ${me.firstName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_dashboardStatsProvider),
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load stats: $e'))],
          ),
          data: (s) => GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              KpiCard(label: 'Total Employees', value: '${s.totalEmployees}', icon: Icons.people, color: Colors.blue),
              KpiCard(label: 'Present Today', value: '${s.presentToday}', icon: Icons.check_circle, color: Colors.green),
              KpiCard(label: 'On Leave', value: '${s.onLeaveToday}', icon: Icons.beach_access, color: Colors.orange),
              KpiCard(label: 'Payroll Due', value: '${s.payrollDue}', icon: Icons.payments, color: Colors.purple),
            ],
          ),
        ),
      ),
    );
  }
}
