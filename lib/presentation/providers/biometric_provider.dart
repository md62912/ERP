import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/biometric_service.dart';
import '../../data/datasources/local/local_cache.dart';

/// Storage key for the biometric-lock device preference, exposed so the
/// Settings screen can write it directly when the person toggles it.
const biometricLockKey = 'biometric_lock_enabled';

/// Whether the person has turned on "require biometric to open app" in
/// Settings. Persisted locally per device (not synced -- it's a device
/// preference, not account data). Seeded synchronously from the cache at
/// provider creation, then held in memory so the Settings toggle can
/// update it immediately without a rebuild-from-disk round trip.
final biometricLockEnabledProvider = StateProvider<bool>((ref) {
  return LocalCache.getBool(biometricLockKey);
});

/// Whether this device's hardware supports biometric authentication at
/// all (doesn't guarantee anything is enrolled -- that's surfaced as an
/// authentication failure if the person tries and has nothing set up).
final isBiometricSupportedProvider = FutureProvider<bool>((ref) async {
  return BiometricService.isSupported();
});

/// Whether the app has already been unlocked THIS PROCESS LIFETIME. Resets
/// on a full app restart, but not merely on backgrounding/foregrounding --
/// the gate is a cold-start lock, not a re-lock-on-every-background one.
final appUnlockedThisSessionProvider = StateProvider<bool>((ref) => false);
