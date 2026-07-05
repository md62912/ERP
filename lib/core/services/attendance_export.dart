import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import '../utils/attendance_rules.dart';
import '../utils/formatters.dart';

/// Builds an Excel-openable CSV of a day's attendance roster and opens the
/// platform share sheet (on web this downloads the file; on Android/iOS it
/// offers the native share/save options). Uses share_plus so no
/// platform-specific file-path handling is needed.
///
/// [employees] is the full active roster so people with no attendance row
/// still appear as Absent; [roster] maps employee_id -> attendance row.
Future<void> exportAttendanceCsv({
  required DateTime date,
  required List<Map<String, dynamic>> employees,
  required Map<String, Map<String, dynamic>> roster,
}) async {
  final dateStr = date.toIso8601String().split('T').first;
  final buffer = StringBuffer();

  // Header row.
  buffer.writeln('Employee,Designation,Date,Status,Check In,Check Out,Work Hours');

  for (final e in employees) {
    final id = e['id'] as String;
    final name = '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();
    final designation = (e['designation'] as String?) ?? '';
    final row = roster[id];
    final status = AttendanceRules.label((row?['status'] as String?) ?? 'absent');
    final checkIn = row?['check_in'] != null ? Formatters.time(DateTime.parse(row!['check_in'])) : '';
    final checkOut = row?['check_out'] != null ? Formatters.time(DateTime.parse(row!['check_out'])) : '';
    final hours = (row?['work_hours'] as num?)?.toString() ?? '';

    buffer.writeln([
      _csv(name),
      _csv(designation),
      dateStr,
      status,
      checkIn,
      checkOut,
      hours,
    ].join(','));
  }

  final bytes = utf8.encode(buffer.toString());
  await Share.shareXFiles(
    [XFile.fromData(bytes, mimeType: 'text/csv')],
    fileNameOverrides: ['attendance_$dateStr.csv'],
    subject: 'Attendance report $dateStr',
  );
}

/// Escapes a CSV field: wraps in quotes and doubles internal quotes if it
/// contains a comma, quote, or newline.
String _csv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
