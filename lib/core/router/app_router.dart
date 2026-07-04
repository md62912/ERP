import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/modules/auth/login_screen.dart';
import '../../presentation/modules/auth/reset_password_screen.dart';
import '../../presentation/modules/dashboard/dashboard_screen.dart';
import '../../presentation/modules/employees/employee_list_screen.dart';
import '../../presentation/modules/employees/employee_detail_screen.dart';
import '../../presentation/modules/attendance/attendance_screen.dart';
import '../../presentation/modules/leave/leave_screen.dart';
import '../../presentation/modules/payroll/payroll_screen.dart';
import '../../presentation/modules/crm/crm_screen.dart';
import '../../presentation/modules/more/more_screen.dart';
import '../../presentation/modules/projects/project_list_screen.dart';
import '../../presentation/modules/projects/project_detail_screen.dart';
import '../../presentation/modules/tasks/my_tasks_screen.dart';
import '../../presentation/modules/scheduling/scheduling_screen.dart';
import '../../presentation/shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final isPasswordRecovery = ref.watch(isPasswordRecoveryProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final resettingPassword = state.matchedLocation == '/reset-password';

      // A password-recovery link creates a real (if narrow) session, so
      // isAuthenticated becomes true -- without this check the normal
      // "already signed in, skip login" redirect would bounce the person
      // straight to the dashboard instead of letting them set a new
      // password first.
      if (isPasswordRecovery) return resettingPassword ? null : '/reset-password';
      if (resettingPassword) return '/dashboard'; // stale/direct nav with no active recovery

      if (!isAuthenticated) return loggingIn ? null : '/login';
      if (loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeeListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    EmployeeDetailScreen(employeeId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/attendance', builder: (context, state) => const AttendanceScreen()),
          GoRoute(path: '/leave', builder: (context, state) => const LeaveScreen()),
          GoRoute(path: '/payroll', builder: (context, state) => const PayrollScreen()),
          GoRoute(path: '/crm', builder: (context, state) => const CrmScreen()),
          GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
          GoRoute(
            path: '/projects',
            builder: (context, state) => const ProjectListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ProjectDetailScreen(projectId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/tasks', builder: (context, state) => const MyTasksScreen()),
          GoRoute(path: '/scheduling', builder: (context, state) => const SchedulingScreen()),
        ],
      ),
    ],
  );
});
