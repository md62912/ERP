import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';
import '../../domain/entities/project.dart';
import 'auth_provider.dart';

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
}
