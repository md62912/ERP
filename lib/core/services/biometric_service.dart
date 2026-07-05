import 'package:local_auth/local_auth.dart';

/// Wraps local_auth for the app's biometric-unlock gate. Delegates
/// entirely to whatever the device has enrolled (fingerprint, face
/// unlock, etc.) via the OS's own biometric prompt -- the app doesn't
/// implement or distinguish between biometric types itself.
class BiometricService {
  BiometricService._();

  static final _auth = LocalAuthentication();

  /// Whether this device can plausibly do biometric auth at all (has the
  /// hardware and supports it) -- doesn't guarantee something is enrolled.
  static Future<bool> isSupported() async {
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return deviceSupported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for biometric authentication. Never throws -- returns false
  /// on any failure, cancellation, or platform error so callers can just
  /// branch on a bool rather than handle exceptions.
  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
