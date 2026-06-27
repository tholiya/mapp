import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'deeplink_service.dart';
import 'notification_service.dart';
import 'secure_store.dart';

enum AppPhase { splash, login, locked, web }

/// Single source of truth for the shell's lifecycle: which screen shows, and
/// the in-WebView route to open (from cold-start deep links / notification taps
/// or runtime deep links).
class SessionController extends ChangeNotifier {
  final SecureStore store;
  final AuthService auth;
  final BiometricService biometric;
  final DeepLinkService deepLinks;
  final NotificationService notifications;

  SessionController({
    required this.store,
    required this.auth,
    required this.biometric,
    required this.deepLinks,
    required this.notifications,
  });

  AppPhase _phase = AppPhase.splash;
  AppPhase get phase => _phase;

  AuthUser? _user;
  AuthUser? get user => _user;

  /// Path the WebView should load on first open (cold-start deep link), e.g.
  /// "/booking/123". Null = load the app root.
  String? initialRoute;

  /// Runtime navigation requests (deep link or notification tap while running).
  /// WebViewScreen listens and forwards to React via the bridge.
  final ValueNotifier<String?> incomingRoute = ValueNotifier<String?>(null);

  /// Run once at startup. Decides the first phase and wires runtime listeners.
  Future<void> bootstrap() async {
    await notifications.init();
    notifications.onTapRoute = _pushRoute;

    initialRoute = await deepLinks.initialPath();
    deepLinks.listen(_pushRoute);

    final hasSession = await store.hasSession();
    if (!hasSession) {
      _set(AppPhase.login);
      return;
    }

    _user = await store.readUser();
    final lockEnabled = await store.isBiometricEnabled();
    _set(lockEnabled ? AppPhase.locked : AppPhase.web);
  }

  /// Called after a successful native login.
  Future<void> onLoginSuccess() async {
    _user = await store.readUser();
    _set(AppPhase.web);
  }

  /// Biometric app-unlock succeeded → reveal the WebView.
  void onUnlocked() => _set(AppPhase.web);

  Future<void> logout() async {
    await auth.serverLogout();
    await store.clear();
    _user = null;
    initialRoute = null;
    incomingRoute.value = null;
    _set(AppPhase.login);
  }

  void _pushRoute(String route) {
    if (_phase == AppPhase.web) {
      incomingRoute.value = route;
    } else {
      // Not yet showing the WebView — remember it as the first route to open.
      initialRoute = route;
    }
  }

  void _set(AppPhase p) {
    _phase = p;
    notifyListeners();
  }

  @override
  void dispose() {
    incomingRoute.dispose();
    deepLinks.dispose();
    super.dispose();
  }
}
