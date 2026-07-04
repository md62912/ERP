import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';

final _leadsProvider = FutureProvider.autoDispose((ref) async {
  final rows = await SupabaseService.client
      .from(Tables.leads)
      .select()
      .order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

final _dealsProvider = FutureProvider.autoDispose((ref) async {
  final rows = await SupabaseService.client
      .from(Tables.deals)
      .select()
      .order('expected_close_date', ascending: true);
  return (rows as List).cast<Map<String, dynamic>>();
});

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
                return leads.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Failed to load leads: $e')),
                  data: (rows) => ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final l = rows[i];
                      return ListTile(
                        title: Text(l['name'] as String),
                        subtitle: Text(l['company'] as String? ?? ''),
                        trailing: Chip(label: Text(l['status'] as String)),
                      );
                    },
                  ),
                );
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final deals = ref.watch(_dealsProvider);
                return deals.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Failed to load deals: $e')),
                  data: (rows) => ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final d = rows[i];
                      return ListTile(
                        title: Text(d['title'] as String),
                        subtitle: Text('Stage: ${d['stage']}'),
                        trailing: Text(Formatters.currency(d['value'])),
                      );
                    },
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
