import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/biometric_service.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';

/// Biometric gate shown on relaunch when a session exists and app-unlock is
/// enabled. Restores the session into the WebView without re-login.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_running) return;
    setState(() => _running = true);
    final biometric = context.read<BiometricService>();
    final session = context.read<SessionController>();
    final result = await biometric.authenticate('Unlock BednBite');
    if (!mounted) return;
    if (result == BiometricResult.success) {
      session.onUnlocked();
    } else {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.page,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLockup(),
              const SizedBox(height: 40),
              const Icon(Icons.fingerprint,
                  size: 56, color: BrandColors.indigoHover),
              const SizedBox(height: 16),
              const Text(
                'Unlock to continue',
                style: TextStyle(color: BrandColors.textSecondary),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _running ? null : _unlock,
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 48),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.read<SessionController>().logout(),
                child: const Text('Sign in with password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
