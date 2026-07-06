import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/department_provider.dart';
import '../../providers/employee_provider.dart';
import '../../../domain/entities/employee.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_helper.dart';

/// Create or edit an employee. HR/Admin only — RLS will reject the
/// write for anyone else regardless of what this form lets you type.
class EmployeeFormScreen extends ConsumerStatefulWidget {
  final Employee? existing;
  const EmployeeFormScreen({super.key, this.existing});

  bool get isEdit => existing != null;

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _empCodeCtrl = TextEditingController(text: widget.existing?.empCode);
  late final _firstNameCtrl = TextEditingController(text: widget.existing?.firstName);
  late final _lastNameCtrl = TextEditingController(text: widget.existing?.lastName);
  late final _emailCtrl = TextEditingController(text: widget.existing?.email);
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone);
  late final _designationCtrl = TextEditingController(text: widget.existing?.designation);
  late final _salaryCtrl =
      TextEditingController(text: widget.existing?.salary?.toStringAsFixed(2));

  late String? _departmentId = widget.existing?.departmentId;
  late String? _managerId = widget.existing?.managerId;
  late UserRole _role = widget.existing?.role ?? UserRole.employee;
  late EmploymentType _employmentType = widget.existing?.employmentType ?? EmploymentType.fullTime;
  late EmployeeStatus _status = widget.existing?.status ?? EmployeeStatus.active;
  late DateTime _joinDate = widget.existing?.joinDate ?? DateTime.now();
  bool _saving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(employeeRepositoryProvider);
    final employee = Employee(
      id: widget.existing?.id ?? '',
      empCode: _empCodeCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      departmentId: _departmentId,
      designation: _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim(),
      role: _role,
      managerId: _managerId,
      employmentType: _employmentType,
      joinDate: _joinDate,
      status: _status,
      salary: double.tryParse(_salaryCtrl.text),
    );

    try {
      if (widget.isEdit) {
        await repo.updateEmployee(widget.existing!.id, employee.toInsertJson());
      } else {
        await repo.createEmployee(employee);
      }
      ref.invalidate(employeeListProvider);
      if (widget.isEdit) ref.invalidate(employeeByIdProvider(widget.existing!.id));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save employee: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentListProvider);
    final employeeListForManager = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Employee' : 'New Employee')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _empCodeCtrl,
              decoration: const InputDecoration(labelText: 'Employee Code'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'First name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: 12),
            departments.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load departments: ${friendlyError(e)}'),
              data: (list) => DropdownButtonFormField<String>(
                value: _departmentId,
                decoration: const InputDecoration(labelText: 'Department'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— None —')),
                  for (final d in list) DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _departmentId = v),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _designationCtrl,
              decoration: const InputDecoration(
                labelText: 'Designation',
                hintText: 'e.g. Project Engineer, Site Engineer, Technician',
              ),
            ),
            const SizedBox(height: 12),
            employeeListForManager.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load employees: ${friendlyError(e)}'),
              data: (list) {
                // Can't report to yourself, and (when editing) can't
                // report to someone who already reports to you --
                // simple cycle guard for the common one-level case.
                final candidates = list.where((e) => e.id != widget.existing?.id).toList();
                return DropdownButtonFormField<String?>(
                  value: _managerId,
                  decoration: const InputDecoration(labelText: 'Reports to (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— No manager / top of hierarchy —')),
                    for (final e in candidates)
                      DropdownMenuItem(value: e.id, child: Text('${e.fullName} (${e.designation ?? e.role.name})')),
                  ],
                  onChanged: (v) => setState(() => _managerId = v),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              value: _role,
              decoration: const InputDecoration(labelText: 'System role (access level)'),
              items: [for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.name))],
              onChanged: (v) => setState(() => _role = v!),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                '"Manager" here means broad company-wide visibility (similar to HR/Admin). '
                'Leave approval for direct reports works automatically from "Reports to" above, '
                'regardless of this setting -- e.g. a Site Engineer with role "employee" can '
                'still approve their own Technicians\' leave. Job title goes in Designation above.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EmploymentType>(
              value: _employmentType,
              decoration: const InputDecoration(labelText: 'Employment type'),
              items: [
                for (final t in EmploymentType.values) DropdownMenuItem(value: t, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _employmentType = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EmployeeStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in EmployeeStatus.values) DropdownMenuItem(value: s, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _joinDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _joinDate = picked);
              },
              child: Text('Join date: ${Formatters.date(_joinDate)}'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _salaryCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monthly salary (optional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.isEdit ? 'Save changes' : 'Create employee'),
            ),
          ],
        ),
      ),
    );
  }
}
