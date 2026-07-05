import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/async_states.dart';
import 'employee_dashboard_screen.dart';
import 'hr_admin_dashboard_screen.dart';

/// Routes to a role-specific dashboard rather than showing one generic
/// view to everyone: hr/admin get an org-wide operational view, everyone
/// else (including managers, who additionally see a team-approvals card)
/// gets a personal one.
///
/// Watches the full async state of the profile (not just its value) so a
/// slow or failed profile load shows a spinner / retry instead of silently
/// rendering the employee dashboard for an admin, or hanging.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeAsync = ref.watch(currentEmployeeProvider);

    return employeeAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(currentEmployeeProvider),
        ),
      ),
      data: (employee) {
        // Signed in but no profile row yet (should be rare now that signup
        // auto-provisions one). Show a clear message rather than a broken
        // dashboard.
        if (employee == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Your profile is still being set up',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "If you just signed up, confirm your email and sign in again. "
                      "If this persists, an admin can check your employee record.",
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(currentEmployeeProvider),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => ref.read(authControllerProvider).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final isHrAdmin = employee.role == UserRole.admin || employee.role == UserRole.hr;
        return isHrAdmin ? const HrAdminDashboardScreen() : const EmployeeDashboardScreen();
      },
    );
  }
}
