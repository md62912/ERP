import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/employee_repository_impl.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl();
});

/// Search text driving the employee list screen.
final employeeSearchProvider = StateProvider<String>((ref) => '');

final employeeListProvider = FutureProvider.autoDispose<List<Employee>>((ref) async {
  final search = ref.watch(employeeSearchProvider);
  final repo = ref.watch(employeeRepositoryProvider);
  return repo.getEmployees(search: search);
});

final employeeByIdProvider =
    FutureProvider.autoDispose.family<Employee, String>((ref, id) async {
  final repo = ref.watch(employeeRepositoryProvider);
  return repo.getEmployeeById(id);
});
