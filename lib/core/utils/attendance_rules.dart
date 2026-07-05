import 'package:flutter/material.dart';

/// Centralized attendance policy + the logic that derives a day's status
/// and paid hours from raw check-in/out timestamps.
///
/// These thresholds are the company's attendance rules in one place. They
/// default to a standard 9-to-5 with a 15-minute grace window, but are the
/// single spot to change if the business adopts different hours. (A future
/// enhancement could move these into a DB table for per-department shifts;
/// for now they're app-level constants so the rules are explicit and
/// testable rather than scattered magic numbers.)
class AttendanceRules {
  AttendanceRules._();

  /// Standard work day start (local time). Check-ins after this + grace are "late".
  static const int workStartHour = 9;
  static const int workStartMinute = 0;

  /// Standard work day end (local time). Used for expected-hours context.
  static const int workEndHour = 17;
  static const int workEndMinute = 0;

  /// Grace window in minutes before a check-in counts as late.
  static const int lateGraceMinutes = 15;

  /// A full standard day, in hours. Overtime accrues beyond this.
  static const double standardWorkHours = 8.0;

  /// Worked hours at/under this count as a half day (when below a full day).
  static const double halfDayThresholdHours = 4.0;

  /// The attendance status values that exist in the DB enum.
  /// (present, late, absent, half_day, holiday)

  /// Expected start DateTime on a given calendar day.
  static DateTime expectedStart(DateTime day) =>
      DateTime(day.year, day.month, day.day, workStartHour, workStartMinute);

  /// The latest a check-in can be before it's "late".
  static DateTime latenessCutoff(DateTime day) =>
      expectedStart(day).add(const Duration(minutes: lateGraceMinutes));

  /// True if a check-in at [checkIn] on its own day is late.
  static bool isLate(DateTime checkIn) =>
      checkIn.isAfter(latenessCutoff(checkIn));

  /// Whole hours worked between check-in and check-out (0 if either missing
  /// or if out precedes in). Rounded to 2 decimals.
  static double workHours({DateTime? checkIn, DateTime? checkOut}) {
    if (checkIn == null || checkOut == null) return 0;
    final mins = checkOut.difference(checkIn).inMinutes;
    if (mins <= 0) return 0;
    return double.parse((mins / 60.0).toStringAsFixed(2));
  }

  /// Overtime hours (worked beyond a standard day). 0 if under standard.
  static double overtimeHours({DateTime? checkIn, DateTime? checkOut}) {
    final worked = workHours(checkIn: checkIn, checkOut: checkOut);
    final ot = worked - standardWorkHours;
    return ot > 0 ? double.parse(ot.toStringAsFixed(2)) : 0;
  }

  /// Derives the appropriate status for a completed (or in-progress) day.
  ///
  /// Rules, in order:
  ///  * No check-in at all  -> 'absent'
  ///  * Checked in but not out yet -> 'late' if the check-in was late, else 'present'
  ///  * Checked in and out:
  ///      - worked <= half-day threshold AND less than a full day -> 'half_day'
  ///      - else -> 'late' if check-in was late, else 'present'
  static String deriveStatus({DateTime? checkIn, DateTime? checkOut}) {
    if (checkIn == null) return 'absent';

    if (checkOut == null) {
      return isLate(checkIn) ? 'late' : 'present';
    }

    final worked = workHours(checkIn: checkIn, checkOut: checkOut);
    if (worked > 0 && worked <= halfDayThresholdHours && worked < standardWorkHours) {
      return 'half_day';
    }
    return isLate(checkIn) ? 'late' : 'present';
  }

  /// Human-readable label for a status value.
  static String label(String status) => switch (status) {
        'present' => 'Present',
        'late' => 'Late',
        'absent' => 'Absent',
        'half_day' => 'Half day',
        'holiday' => 'Holiday',
        _ => status,
      };

  /// Consistent status color used across attendance UI.
  static Color color(String status) => switch (status) {
        'present' => Colors.green,
        'late' => Colors.orange,
        'absent' => Colors.red,
        'half_day' => Colors.amber,
        'holiday' => Colors.blueGrey,
        _ => Colors.blueGrey,
      };
}
