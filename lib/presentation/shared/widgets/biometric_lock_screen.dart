import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/biometric_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';

/// Shown instead of the app shell when biometric lock is enabled and this
/// process hasn't been unlocked yet. A deliberate tap-to-unlock button
/// (rather than auto-firing the OS prompt from build()) avoids the prompt
/// re-triggering or stacking across rebuilds.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _authenticating = false;
  bool _lastAttemptFailed = false;

  Future<void> _unlock() async {
    setState(() {
      _authenticating = true;
      _lastAttemptFailed = false;
    });
    final success = await BiometricService.authenticate(reason: 'Unlock Xebec ERP');
    if (!mounted) return;
    if (success) {
      ref.read(appUnlockedThisSessionProvider.notifier).state = true;
    } else {
      setState(() {
        _authenticating = false;
        _lastAttemptFailed = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Offer the prompt right away on first load, but only once -- if it
    // fails or is dismissed, the person taps the button to retry rather
    // than being re-prompted automatically.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.fingerprint, size: 56, color: colorScheme.primary),
                ),
                const SizedBox(height: 24),
                Text('Xebec ERP is locked', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  _lastAttemptFailed
                      ? "Couldn't verify your biometric. Try again."
                      : 'Use your fingerprint or face to continue.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _unlock,
                  icon: _authenticating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_open),
                  label: Text(_authenticating ? 'Verifying…' : 'Unlock'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.read(authControllerProvider).signOut(),
                  child: const Text('Sign out instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
