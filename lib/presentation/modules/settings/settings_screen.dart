import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/biometric_service.dart';
import '../../../data/datasources/local/local_cache.dart';
import '../../providers/biometric_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockEnabled = ref.watch(biometricLockEnabledProvider);
    final supported = ref.watch(isBiometricSupportedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: supported.when(
              loading: () => const ListTile(
                leading: Icon(Icons.fingerprint),
                title: Text('Biometric lock'),
                subtitle: Text('Checking device support…'),
              ),
              error: (_, __) => const ListTile(
                leading: Icon(Icons.fingerprint),
                title: Text('Biometric lock'),
                subtitle: Text('Could not check device support'),
              ),
              data: (isSupported) {
                if (!isSupported) {
                  return const ListTile(
                    leading: Icon(Icons.fingerprint, color: Colors.grey),
                    title: Text('Biometric lock'),
                    subtitle: Text('Not available on this device'),
                  );
                }
                return SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Require biometric to open app'),
                  subtitle: const Text(
                    "Uses your device's fingerprint or face unlock. Applies the next time you open the app.",
                  ),
                  value: lockEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Confirm biometric actually works before turning the
                      // gate on, so someone can't lock themselves out by
                      // enabling it on a device with nothing enrolled.
                      final confirmed = await BiometricService.authenticate(
                        reason: 'Confirm biometric to enable app lock',
                      );
                      if (!confirmed) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Couldn't confirm biometric — lock was not enabled.")),
                          );
                        }
                        return;
                      }
                    }
                    await LocalCache.setBool(biometricLockKey, value);
                    ref.read(biometricLockEnabledProvider.notifier).state = value;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
