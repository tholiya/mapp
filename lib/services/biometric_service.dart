import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

enum BiometricResult { success, failed, unavailable }

/// Wraps local_auth for two uses:
///  1. App-unlock on relaunch (restore the stored session without re-login).
///  2. React-triggered step-up via the JS bridge for sensitive actions.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// True only when the device has biometrics enrolled and usable.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported && !canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty || supported;
    } on PlatformException {
      return false;
    }
  }

  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason.isEmpty ? 'Verify your identity' : reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN/passcode fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'BednBite',
            biometricHint: '',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(cancelButton: 'Cancel'),
        ],
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException {
      return BiometricResult.unavailable;
    }
  }
}
