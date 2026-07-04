import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/employee.dart';
import '../payroll/payroll_admin_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final canManage = role == UserRole.admin || role == UserRole.hr;

    final tiles = [
      (icon: Icons.folder_special_outlined, label: 'Projects', path: '/projects', color: Colors.indigo),
      (icon: Icons.checklist_rounded, label: 'My Tasks', path: '/tasks', color: Colors.teal),
      (icon: Icons.calendar_month_outlined, label: 'Schedule', path: '/scheduling', color: Colors.deepOrange),
      (icon: Icons.handshake_outlined, label: 'CRM', path: '/crm', color: Colors.purple),
      if (canManage)
        (icon: Icons.admin_panel_settings_outlined, label: 'Payroll Admin', path: '__payroll_admin', color: Colors.brown),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          for (final tile in tiles)
            _ModuleTile(
              icon: tile.icon,
              label: tile.label,
              color: tile.color,
              onTap: () => tile.path == '__payroll_admin'
                  ? Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollAdminScreen()))
                  : context.push(tile.path),
            ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModuleTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
