import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';
import '../../domain/entities/project.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

final projectListProvider = FutureProvider.autoDispose<List<Project>>((ref) async {
  final rows = await SupabaseService.client
      .from(Tables.projects)
      .select()
      .order('created_at', ascending: false);
  return (rows as List).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
});

final projectByIdProvider =
    FutureProvider.autoDispose.family<Project, String>((ref, id) async {
  final row = await SupabaseService.client.from(Tables.projects).select().eq('id', id).single();
  return Project.fromJson(row);
});

final projectTasksProvider =
    FutureProvider.autoDispose.family<List<ProjectTask>, String>((ref, projectId) async {
  final rows = await SupabaseService.client
      .from(Tables.tasks)
      .select()
      .eq('project_id', projectId)
      .order('created_at');
  return (rows as List).map((e) => ProjectTask.fromJson(e as Map<String, dynamic>)).toList();
});

final projectMilestonesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  final rows = await SupabaseService.client
      .from(Tables.milestones)
      .select()
      .eq('project_id', projectId)
      .order('due_date');
  return (rows as List).cast<Map<String, dynamic>>();
});

/// Team members currently on a project, joined with employee details.
final projectMembersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  final rows = await SupabaseService.client
      .from(Tables.projectMembers)
      .select('*, employees(id, first_name, last_name, designation)')
      .eq('project_id', projectId)
      .order('joined_at');
  return (rows as List).cast<Map<String, dynamic>>();
});

final projectMemberActionsProvider = Provider((ref) => ProjectMemberActions());

class ProjectMemberActions {
  Future<void> addMember({
    required String projectId,
    required String employeeId,
    String roleInProject = 'member',
  }) async {
    await SupabaseService.client.from(Tables.projectMembers).insert({
      'project_id': projectId,
      'employee_id': employeeId,
      'role_in_project': roleInProject,
    });
  }

  Future<void> updateMemberRole(String memberRowId, String roleInProject) async {
    await SupabaseService.client
        .from(Tables.projectMembers)
        .update({'role_in_project': roleInProject}).eq('id', memberRowId);
  }

  Future<void> removeMember(String memberRowId) async {
    await SupabaseService.client.from(Tables.projectMembers).delete().eq('id', memberRowId);
  }
}

/// Tasks assigned to the signed-in employee, across all projects —
/// this is the "My Tasks" tracking view.
final myTasksProvider = FutureProvider.autoDispose<List<ProjectTask>>((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return [];
  final rows = await SupabaseService.client
      .from(Tables.tasks)
      .select()
      .eq('assignee_id', me.id)
      .order('due_date');
  return (rows as List).map((e) => ProjectTask.fromJson(e as Map<String, dynamic>)).toList();
});

final taskRepositoryProvider = Provider((ref) => TaskActions());

class TaskActions {
  Future<void> updateStatus(String taskId, TaskStatus status) async {
    await SupabaseService.client
        .from(Tables.tasks)
        .update({'status': enumToDb(status)}).eq('id', taskId);
  }

  Future<void> logTime({
    required String taskId,
    required String employeeId,
    required double hours,
    String? note,
  }) async {
    await SupabaseService.client.from(Tables.timeLogs).insert({
      'task_id': taskId,
      'employee_id': employeeId,
      'hours': hours,
      'note': note,
    });
  }

  /// Creates a task under a project. RLS restricts this to the project's
  /// owner or hr/admin/manager -- if the signed-in user isn't one of
  /// those, Supabase rejects the insert and this throws.
  Future<void> createTask({
    required String projectId,
    required String title,
    String? description,
    String? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    required String createdBy,
  }) async {
    await SupabaseService.client.from(Tables.tasks).insert({
      'project_id': projectId,
      'title': title,
      'description': description,
      'assignee_id': assigneeId,
      'priority': enumToDb(priority),
      'due_date': dueDate?.toIso8601String().split('T').first,
      'created_by': createdBy,
    });

    if (assigneeId != null && assigneeId != createdBy) {
      try {
        await NotificationActions().notify(
          employeeId: assigneeId,
          title: 'New task assigned',
          body: title,
        );
      } catch (_) {
        // Non-critical -- the task itself was already created successfully.
      }
    }
  }
}

final projectActionsProvider = Provider((ref) => ProjectActions());

class ProjectActions {
  /// Creates a project owned by [ownerId]. RLS allows anyone to create a
  /// project they own (owner_id = auth_employee_id() always satisfies the
  /// policy), or hr/admin/manager to create on behalf of anyone.
  Future<void> createProject({
    required String name,
    String? description,
    required String ownerId,
    ProjectStatus status = ProjectStatus.planning,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
  }) async {
    await SupabaseService.client.from(Tables.projects).insert({
      'name': name,
      'description': description,
      'owner_id': ownerId,
      'status': enumToDb(status),
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'budget': budget,
    });
  }
}
