import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/lock_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/webview_screen.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/connectivity_service.dart';
import 'services/deeplink_service.dart';
import 'services/download_service.dart';
import 'services/notification_service.dart';
import 'services/secure_store.dart';
import 'services/session_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Compose the (mostly stateless) service graph once.
  final store = SecureStore();
  final auth = AuthService(store);
  final biometric = BiometricService();
  final deepLinks = DeepLinkService();
  final notifications = NotificationService();
  final connectivity = ConnectivityService();
  final downloads = DownloadService(store, notifications);

  final session = SessionController(
    store: store,
    auth: auth,
    biometric: biometric,
    deepLinks: deepLinks,
    notifications: notifications,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<SecureStore>.value(value: store),
        Provider<AuthService>.value(value: auth),
        Provider<BiometricService>.value(value: biometric),
        Provider<NotificationService>.value(value: notifications),
        Provider<DownloadService>.value(value: downloads),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ChangeNotifierProvider<SessionController>.value(value: session),
      ],
      child: const BednBiteApp(),
    ),
  );
}

class BednBiteApp extends StatelessWidget {
  const BednBiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BednBite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AppRoot(),
    );
  }
}

/// Boots the session once, then renders the screen for the current phase.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ConnectivityService>().start();
      if (!mounted) return;
      await context.read<SessionController>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<SessionController>().phase;
    switch (phase) {
      case AppPhase.splash:
        return const SplashScreen();
      case AppPhase.login:
        return const LoginScreen();
      case AppPhase.locked:
        return const LockScreen();
      case AppPhase.web:
        return const WebViewScreen();
    }
  }
}
