import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/biometric_provider.dart';
import 'biometric_lock_screen.dart';
import 'responsive_body.dart';

/// Shared bottom-nav shell. Wraps every authenticated screen so the tab
/// bar persists across navigation (state is preserved per GoRouter's
/// ShellRoute behavior).
///
/// Also hosts the biometric-lock gate: if enabled and this process hasn't
/// been unlocked yet, shows BiometricLockScreen instead of the shell
/// content. This sits here (rather than in the router's redirect logic)
/// because the lock is a cold-start overlay on top of an already-valid
/// session, not a routing decision -- the person IS authenticated, the
/// gate just hasn't been passed yet this app launch.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    (path: '/dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Home'),
    (path: '/employees', icon: Icons.people_outline, activeIcon: Icons.people, label: 'People'),
    (path: '/attendance', icon: Icons.fingerprint, activeIcon: Icons.fingerprint, label: 'Attendance'),
    (path: '/leave', icon: Icons.beach_access_outlined, activeIcon: Icons.beach_access, label: 'Leave'),
    (path: '/payroll', icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Payroll'),
    (path: '/more', icon: Icons.apps_outlined, activeIcon: Icons.apps, label: 'More'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexWhere((t) => location.startsWith(t.path));
    if (index != -1) return index;
    // Secondary modules (projects, tasks, scheduling, crm) live under the
    // "More" hub even though they have their own routes, so highlight that tab.
    const secondaryPrefixes = ['/projects', '/tasks', '/scheduling', '/crm'];
    if (secondaryPrefixes.any(location.startsWith)) {
      return _tabs.indexWhere((t) => t.path == '/more');
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockEnabled = ref.watch(biometricLockEnabledProvider);
    final unlocked = ref.watch(appUnlockedThisSessionProvider);
    if (lockEnabled && !unlocked) {
      return const BiometricLockScreen();
    }

    final currentIndex = _currentIndex(context);
    return Scaffold(
      body: ResponsiveBody(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => context.go(_tabs[index].path),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
