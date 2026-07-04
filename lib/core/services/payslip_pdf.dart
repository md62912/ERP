import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/formatters.dart';

const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Builds a one-page payslip PDF and opens the platform's print/share
/// sheet for it (works on web, Android, and iOS via the `printing`
/// package -- no platform-specific file-path handling needed).
Future<void> sharePayslipPdf({
  required Map<String, dynamic> payslip,
  required String employeeName,
  required String empCode,
}) async {
  final doc = pw.Document();
  final run = payslip['payroll_runs'] as Map?;
  final month = run?['month'] as int?;
  final year = run?['year'];
  final periodLabel = month == null ? 'Payslip' : '${_monthNames[month]} $year';

  final basic = (payslip['basic_salary'] as num?) ?? 0;
  final allowances = (payslip['total_allowances'] as num?) ?? 0;
  final deductions = (payslip['total_deductions'] as num?) ?? 0;
  final gross = (payslip['gross_salary'] as num?) ?? 0;
  final net = (payslip['net_salary'] as num?) ?? 0;
  final paidDays = payslip['paid_days'];
  final absentDays = payslip['absent_days'];

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Xebec Trading Services', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Payslip', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(periodLabel, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employee', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text(employeeName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employee Code', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text(empCode, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (paidDays != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Paid / Absent Days', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('$paidDays / ${absentDays ?? 0}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _breakdownTable('Earnings', {'Basic Salary': basic, 'Allowances': allowances}, gross)),
                pw.SizedBox(width: 16),
                pw.Expanded(child: _breakdownTable('Deductions', {'Total Deductions': deductions}, deductions)),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Net Pay', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(Formatters.currency(net), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'This is a system-generated payslip and does not require a signature.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) => doc.save(), name: 'Payslip_${periodLabel.replaceAll(' ', '_')}.pdf');
}

pw.Widget _breakdownTable(String title, Map<String, num> rows, num total) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      for (final entry in rows.entries)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(entry.key, style: const pw.TextStyle(fontSize: 10)),
              pw.Text(Formatters.currency(entry.value), style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      pw.Divider(color: PdfColors.grey300, height: 12),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(Formatters.currency(total), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ],
  );
}
