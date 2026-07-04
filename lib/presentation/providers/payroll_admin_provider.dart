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

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  bool _isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  String _iso(DateTime d) => d.toIso8601String().split('T').first;

  /// Inclusive overlap, in days, between two date ranges. Used to figure
  /// out how much of an approved leave request actually falls inside the
  /// payroll month (a leave spanning month boundaries shouldn't count in
  /// full against either month).
  int _overlapDays(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    final start = aStart.isAfter(bStart) ? aStart : bStart;
    final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    final diff = end.difference(start).inDays + 1;
    return diff > 0 ? diff : 0;
  }

  /// Pulls every active employee's current salary structure, prorates it
  /// against actual attendance for the run's month, and writes one
  /// payslip per employee.
  ///
  /// Proration model: `paid_days = present_days + approved_paid_leave_days`
  /// (capped at the month's total working days); everything else counts
  /// as unpaid absence. Earnings (basic + allowances) scale with
  /// `paid_days / total_working_days`; deductions are left un-prorated
  /// since things like tax/insurance are typically flat statutory amounts
  /// rather than pay-period-proportional. Working days exclude weekends
  /// and any date in the `holidays` table for that month.
  Future<int> generatePayslips(String runId) async {
    final client = SupabaseService.client;

    final run = await client.from(Tables.payrollRuns).select().eq('id', runId).single();
    final month = run['month'] as int;
    final year = run['year'] as int;
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month, _daysInMonth(year, month));

    final holidayRows = await client
        .from(Tables.holidays)
        .select('date')
        .gte('date', _iso(monthStart))
        .lte('date', _iso(monthEnd));
    final holidayDates = {for (final h in holidayRows as List) h['date'] as String};

    var totalWorkingDays = 0;
    for (var d = monthStart; !d.isAfter(monthEnd); d = d.add(const Duration(days: 1))) {
      if (!_isWeekend(d) && !holidayDates.contains(_iso(d))) totalWorkingDays++;
    }
    // Guard against a misconfigured month with zero working days (shouldn't
    // normally happen, but would otherwise divide by zero below).
    if (totalWorkingDays == 0) totalWorkingDays = _daysInMonth(year, month);

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

      // Attendance within the month: present/late count as a full day,
      // half_day counts as half.
      final attendanceRows = await client
          .from(Tables.attendance)
          .select('status')
          .eq('employee_id', employeeId)
          .gte('date', _iso(monthStart))
          .lte('date', _iso(monthEnd));
      double presentDays = 0;
      for (final a in attendanceRows as List) {
        final status = a['status'] as String;
        if (status == 'present' || status == 'late') {
          presentDays += 1;
        } else if (status == 'half_day') {
          presentDays += 0.5;
        }
      }

      // Approved leave on a paid leave type, clipped to the days that
      // actually fall within this month.
      final leaveRows = await client
          .from(Tables.leaveRequests)
          .select('from_date, to_date, leave_types!inner(is_paid)')
          .eq('employee_id', employeeId)
          .eq('status', 'approved')
          .eq('leave_types.is_paid', true)
          .lte('from_date', _iso(monthEnd))
          .gte('to_date', _iso(monthStart));
      double paidLeaveDays = 0;
      for (final l in leaveRows as List) {
        final from = DateTime.parse(l['from_date'] as String);
        final to = DateTime.parse(l['to_date'] as String);
        paidLeaveDays += _overlapDays(from, to, monthStart, monthEnd);
      }

      final paidDays = (presentDays + paidLeaveDays).clamp(0, totalWorkingDays.toDouble());
      final absentDays = totalWorkingDays - paidDays;
      final prorationRatio = paidDays / totalWorkingDays;

      final proratedBasic = basic * prorationRatio;
      final proratedAllowances = allowances * prorationRatio;
      final gross = proratedBasic + proratedAllowances;
      final net = gross - deductions;

      await client.from(Tables.payslips).upsert({
        'payroll_run_id': runId,
        'employee_id': employeeId,
        'basic_salary': proratedBasic,
        'total_allowances': proratedAllowances,
        'total_deductions': deductions,
        'gross_salary': gross,
        'net_salary': net,
        'paid_days': paidDays.round(),
        'absent_days': absentDays.round(),
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
