import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_config.dart';

/// Thin wrapper around the Supabase singleton so the rest of the app
/// never talks to `Supabase.instance` directly — makes it trivial to
/// swap in a fake client for tests.
class SupabaseService {
  SupabaseService._();

  static Future<void> init() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static User? get currentUser => client.auth.currentUser;
}

/// Table name constants — keep in sync with supabase/migrations.
class Tables {
  Tables._();
  static const departments = 'departments';
  static const employees = 'employees';
  static const employeeDocuments = 'employee_documents';
  static const attendance = 'attendance';
  static const leaveTypes = 'leave_types';
  static const leaveBalances = 'leave_balances';
  static const leaveRequests = 'leave_requests';
  static const holidays = 'holidays';
  static const salaryStructures = 'salary_structures';
  static const payrollRuns = 'payroll_runs';
  static const payslips = 'payslips';
  static const expenseClaims = 'expense_claims';
  static const clients = 'clients';
  static const leads = 'leads';
  static const deals = 'deals';
  static const crmActivities = 'crm_activities';
  static const notifications = 'notifications';
  static const projects = 'projects';
  static const projectMembers = 'project_members';
  static const milestones = 'milestones';
  static const tasks = 'tasks';
  static const taskComments = 'task_comments';
  static const timeLogs = 'time_logs';
  static const scheduleEvents = 'schedule_events';
  static const scheduleAttendees = 'schedule_attendees';
}
