import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/modules/auth/login_screen.dart';
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

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      if (!isAuthenticated) return loggingIn ? null : '/login';
      if (loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
