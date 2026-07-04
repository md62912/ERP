/// Mirrors the `user_role` enum in Postgres.
enum UserRole { admin, hr, manager, employee }

/// Mirrors the `employee_status` enum in Postgres.
enum EmployeeStatus { active, inactive, terminated, onLeave }

/// Mirrors the `employment_type` enum in Postgres.
enum EmploymentType { fullTime, partTime, contract, intern }

UserRole userRoleFromString(String value) => UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.employee,
    );

EmployeeStatus employeeStatusFromString(String value) =>
    EmployeeStatus.values.firstWhere(
      (e) => _dbName(e) == value,
      orElse: () => EmployeeStatus.active,
    );

EmploymentType? employmentTypeFromString(String? value) {
  if (value == null) return null;
  return EmploymentType.values.firstWhere(
    (e) => _dbName(e) == value,
    orElse: () => EmploymentType.fullTime,
  );
}

/// Converts camelCase enum names to the snake_case values Postgres expects
/// (e.g. EmployeeStatus.onLeave -> 'on_leave').
String _dbName(Enum value) {
  final name = value.name;
  final buffer = StringBuffer();
  for (final rune in name.runes) {
    final char = String.fromCharCode(rune);
    if (char == char.toUpperCase() && char != char.toLowerCase()) {
      buffer.write('_${char.toLowerCase()}');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

class Employee {
  final String id;
  final String? userId;
  final String empCode;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? departmentId;
  final String? designation;
  final UserRole role;
  final String? managerId;
  final EmploymentType? employmentType;
  final DateTime joinDate;
  final EmployeeStatus status;
  final double? salary;

  const Employee({
    required this.id,
    this.userId,
    required this.empCode,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.departmentId,
    this.designation,
    this.role = UserRole.employee,
    this.managerId,
    this.employmentType,
    required this.joinDate,
    this.status = EmployeeStatus.active,
    this.salary,
  });

  String get fullName => '$firstName $lastName';

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        empCode: json['emp_code'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        departmentId: json['department_id'] as String?,
        designation: json['designation'] as String?,
        role: userRoleFromString(json['role'] as String? ?? 'employee'),
        managerId: json['manager_id'] as String?,
        employmentType: employmentTypeFromString(json['employment_type'] as String?),
        joinDate: DateTime.parse(json['join_date'] as String),
        status: employeeStatusFromString(json['status'] as String? ?? 'active'),
        salary: (json['salary'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toInsertJson() => {
        'emp_code': empCode,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'department_id': departmentId,
        'designation': designation,
        'role': role.name,
        'manager_id': managerId,
        'employment_type': employmentType == null ? null : _dbName(employmentType!),
        'join_date': joinDate.toIso8601String().split('T').first,
        'status': _dbName(status),
        'salary': salary,
      };
}
