import '../utils/attendance_rules.dart';
import '../utils/formatters.dart';
// Conditional import: real browser-download impl on web, no-op stub on
// native. This avoids any native share/file plugin (which broke the
// Android build) while keeping CSV export fully working on web.
import 'attendance_export_stub.dart'
    if (dart.library.html) 'attendance_export_web.dart';

/// Builds an Excel-openable CSV of a day's attendance roster and saves it.
/// On web this triggers a browser download; on native it currently throws
/// UnsupportedError (mobile export deferred — see downloadCsv stub).
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

  final csv = buffer.toString();
  downloadCsv(filename: 'attendance_$dateStr.csv', content: csv);
}

/// Escapes a CSV field.
String _csv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
