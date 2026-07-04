import '../entities/employee.dart';

abstract class EmployeeRepository {
  Future<List<Employee>> getEmployees({String? search, String? departmentId});
  Future<Employee> getEmployeeById(String id);
  Future<Employee> getMyProfile();
  Future<Employee> createEmployee(Employee employee);
  Future<Employee> updateEmployee(String id, Map<String, dynamic> changes);
  Future<void> deactivateEmployee(String id);
}
