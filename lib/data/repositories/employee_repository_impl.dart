import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/supabase/supabase_client.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final SupabaseClient _client;

  EmployeeRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  @override
  Future<List<Employee>> getEmployees({String? search, String? departmentId}) async {
    var query = _client.from(Tables.employees).select();

    if (departmentId != null) {
      query = query.eq('department_id', departmentId);
    }
    if (search != null && search.trim().isNotEmpty) {
      query = query.or(
        'first_name.ilike.%$search%,last_name.ilike.%$search%,email.ilike.%$search%,emp_code.ilike.%$search%',
      );
    }

    final rows = await query.order('first_name');
    return (rows as List).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Employee> getEmployeeById(String id) async {
    final row = await _client.from(Tables.employees).select().eq('id', id).single();
    return Employee.fromJson(row);
  }

  @override
  Future<Employee> getMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No authenticated user');
    }
    final row = await _client.from(Tables.employees).select().eq('user_id', uid).single();
    return Employee.fromJson(row);
  }

  @override
  Future<Employee> createEmployee(Employee employee) async {
    final row = await _client
        .from(Tables.employees)
        .insert(employee.toInsertJson())
        .select()
        .single();
    return Employee.fromJson(row);
  }

  @override
  Future<Employee> updateEmployee(String id, Map<String, dynamic> changes) async {
    final row = await _client
        .from(Tables.employees)
        .update(changes)
        .eq('id', id)
        .select()
        .single();
    return Employee.fromJson(row);
  }

  @override
  Future<void> deactivateEmployee(String id) async {
    await _client.from(Tables.employees).update({'status': 'inactive'}).eq('id', id);
  }
}
