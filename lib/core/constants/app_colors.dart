import 'package:flutter/material.dart';

/// Design tokens. Brand color is a modern indigo/violet rather than a flat
/// corporate blue; status colors are shared between light and dark since
/// they're meant to be semantically recognizable regardless of theme.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF6366F1); // indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF14B8A6); // teal

  // Status (same across themes for consistent meaning)
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);

  // Light surfaces
  static const Color lightBackground = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0F1F7);
  static const Color lightTextPrimary = Color(0xFF16171D);
  static const Color lightTextSecondary = Color(0xFF6B6E7A);
  static const Color lightBorder = Color(0xFFE5E6EE);

  // Dark surfaces (tiered elevation, not pure black)
  static const Color darkBackground = Color(0xFF0E0F13);
  static const Color darkSurface = Color(0xFF17181F);
  static const Color darkSurfaceAlt = Color(0xFF1F2129);
  static const Color darkTextPrimary = Color(0xFFF2F2F5);
  static const Color darkTextSecondary = Color(0xFFA0A3B1);
  static const Color darkBorder = Color(0xFF2A2C36);

  /// Status chip backgrounds derive from status colors at low opacity;
  /// helper so screens don't hand-roll withOpacity everywhere.
  static Color statusBg(Color status) => status.withOpacity(0.14);
}
