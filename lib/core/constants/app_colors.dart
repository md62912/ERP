import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2E5AAC);
  static const Color primaryDark = Color(0xFF1B3B73);
  static const Color secondary = Color(0xFF00B894);
  static const Color danger = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color success = Color(0xFF27AE60);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surfaceDark = Color(0xFF14161C);
  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF6B7280);

  // Status colors (attendance / leave / payroll)
  static const Color statusPresent = success;
  static const Color statusAbsent = danger;
  static const Color statusLate = warning;
  static const Color statusPending = warning;
  static const Color statusApproved = success;
  static const Color statusRejected = danger;
}
