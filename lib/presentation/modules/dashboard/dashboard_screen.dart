import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/auth_provider.dart';
import 'employee_dashboard_screen.dart';
import 'hr_admin_dashboard_screen.dart';

/// Routes to a role-specific dashboard rather than showing one generic
/// view to everyone: hr/admin get an org-wide operational view, everyone
/// else (including managers, who additionally see a team-approvals card)
/// gets a personal one.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final isHrAdmin = role == UserRole.admin || role == UserRole.hr;
    return isHrAdmin ? const HrAdminDashboardScreen() : const EmployeeDashboardScreen();
  }
}
