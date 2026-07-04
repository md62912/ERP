import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';

final payrollRunsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(Tables.payrollRuns)
      .select()
      .order('year', ascending: false)
      .order('month', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

final payrollRunPayslipsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, runId) async {
  final rows = await SupabaseService.client
      .from(Tables.payslips)
      .select('*, employees(first_name, last_name, emp_code)')
      .eq('payroll_run_id', runId)
      .order('created_at');
  return (rows as List).cast<Map<String, dynamic>>();
});

final payrollActionsProvider = Provider((ref) => PayrollActions());

class PayrollActions {
  Future<String> createRun({required int month, required int year}) async {
    final row = await SupabaseService.client
        .from(Tables.payrollRuns)
        .insert({'month': month, 'year': year, 'status': 'draft'})
        .select()
        .single();
    return row['id'] as String;
  }

  /// Pulls every active employee's current salary structure, computes
  /// gross/net, and writes one payslip per employee for this run.
  /// Simple formula: gross = basic + allowances, net = gross - deductions.
  /// A real system would prorate for absences/leave; this is a starting point.
  Future<int> generatePayslips(String runId) async {
    final client = SupabaseService.client;

    final employees = await client.from(Tables.employees).select('id').eq('status', 'active');

    var generated = 0;
    for (final emp in employees as List) {
      final employeeId = emp['id'] as String;

      final structures = await client
          .from(Tables.salaryStructures)
          .select()
          .eq('employee_id', employeeId)
          .order('effective_from', ascending: false)
          .limit(1);
      if ((structures as List).isEmpty) continue;
      final s = structures.first as Map<String, dynamic>;

      final basic = (s['basic_salary'] as num?)?.toDouble() ?? 0;
      final allowances = (s['house_allowance'] as num? ?? 0) +
          (s['transport_allowance'] as num? ?? 0) +
          (s['medical_allowance'] as num? ?? 0) +
          (s['other_allowance'] as num? ?? 0);
      final deductions = (s['tax_deduction'] as num? ?? 0) +
          (s['insurance_deduction'] as num? ?? 0) +
          (s['provident_fund'] as num? ?? 0);

      final gross = basic + allowances;
      final net = gross - deductions;

      await client.from(Tables.payslips).upsert({
        'payroll_run_id': runId,
        'employee_id': employeeId,
        'basic_salary': basic,
        'total_allowances': allowances,
        'total_deductions': deductions,
        'gross_salary': gross,
        'net_salary': net,
      }, onConflict: 'payroll_run_id,employee_id');
      generated++;
    }

    final total = await client
        .from(Tables.payslips)
        .select('net_salary')
        .eq('payroll_run_id', runId);
    final totalAmount = (total as List).fold<double>(
      0,
      (sum, row) => sum + ((row['net_salary'] as num?)?.toDouble() ?? 0),
    );

    await client.from(Tables.payrollRuns).update({
      'status': 'processing',
      'total_amount': totalAmount,
    }).eq('id', runId);

    return generated;
  }

  Future<void> markPaid(String runId) async {
    await SupabaseService.client.from(Tables.payrollRuns).update({
      'status': 'paid',
      'processed_at': DateTime.now().toIso8601String(),
    }).eq('id', runId);

    await SupabaseService.client
        .from(Tables.payslips)
        .update({'status': 'sent'}).eq('payroll_run_id', runId);
  }
}
