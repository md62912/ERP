import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';

final _leadsProvider = FutureProvider.autoDispose((ref) async {
  final rows = await SupabaseService.client.from(Tables.leads).select().order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

final _dealsProvider = FutureProvider.autoDispose((ref) async {
  final rows = await SupabaseService.client.from(Tables.deals).select().order('expected_close_date', ascending: true);
  return (rows as List).cast<Map<String, dynamic>>();
});

Color _leadStatusColor(String status) => switch (status) {
      'won' => Colors.green,
      'lost' => Colors.red,
      'qualified' => Colors.blue,
      'proposal' => Colors.purple,
      'contacted' => Colors.orange,
      _ => Colors.blueGrey,
    };

Color _stageColor(String stage) => switch (stage) {
      'closed_won' => Colors.green,
      'closed_lost' => Colors.red,
      'negotiation' => Colors.purple,
      'proposal' => Colors.blue,
      _ => Colors.orange,
    };

class CrmScreen extends ConsumerWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CRM'),
          bottom: const TabBar(tabs: [Tab(text: 'Leads'), Tab(text: 'Deals')]),
        ),
        body: TabBarView(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final leads = ref.watch(_leadsProvider);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_leadsProvider),
                  child: leads.when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorView(error: e),
                    data: (rows) => rows.isEmpty
                        ? const EmptyState(icon: Icons.person_search_outlined, title: 'No leads yet')
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final l = rows[i];
                              final status = l['status'] as String;
                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: _leadStatusColor(status).withOpacity(0.14),
                                    child: Text(
                                      (l['name'] as String).isNotEmpty ? (l['name'] as String)[0].toUpperCase() : '?',
                                      style: TextStyle(color: _leadStatusColor(status), fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  title: Text(l['name'] as String, style: Theme.of(context).textTheme.titleSmall),
                                  subtitle: Text(
                                    [l['company'], if (l['estimated_value'] != null) Formatters.currency(l['estimated_value'])]
                                        .where((e) => e != null)
                                        .join(' · '),
                                  ),
                                  trailing: StatusPill(label: status, color: _leadStatusColor(status)),
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final deals = ref.watch(_dealsProvider);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_dealsProvider),
                  child: deals.when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorView(error: e),
                    data: (rows) => rows.isEmpty
                        ? const EmptyState(icon: Icons.handshake_outlined, title: 'No deals yet')
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final d = rows[i];
                              final stage = d['stage'] as String;
                              final probability = d['probability'] as int? ?? 0;
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(d['title'] as String, style: Theme.of(context).textTheme.titleSmall),
                                          ),
                                          Text(
                                            Formatters.currency(d['value']),
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          StatusPill(label: stage.replaceAll('_', ' '), color: _stageColor(stage)),
                                          const Spacer(),
                                          Text('$probability%', style: Theme.of(context).textTheme.bodySmall),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: probability / 100,
                                          minHeight: 6,
                                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                          color: _stageColor(stage),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
