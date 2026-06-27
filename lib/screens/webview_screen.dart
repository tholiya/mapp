import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bridge/bridge_scripts.dart';
import '../config/app_config.dart';
import '../services/biometric_service.dart';
import '../services/bridge_service.dart';
import '../services/connectivity_service.dart';
import '../services/download_service.dart';
import '../services/secure_store.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import 'offline_view.dart';

/// The shell. Seeds auth (cookie + localStorage) so React boots straight to the
/// dashboard, hosts the app, and bridges native capabilities.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;
  late final PullToRefreshController _pullToRefresh;
  late final BridgeService _bridge;
  ConnectivityService? _connectivity;
  SessionController? _session;

  List<UserScript>? _userScripts;
  WebUri? _initialUrl;
  bool _ready = false;

  int _progress = 0;
  bool _loadError = false;
  bool _firstLoadDone = false;

  @override
  void initState() {
    super.initState();
    _pullToRefresh = PullToRefreshController(
      settings: PullToRefreshSettings(color: BrandColors.indigoHover),
      onRefresh: () async => _controller?.reload(),
    );

    _session = context.read<SessionController>();
    _session!.incomingRoute.addListener(_onIncomingRoute);

    _connectivity = context.read<ConnectivityService>();
    _connectivity!.addListener(_onConnectivityChanged);

    _bridge = BridgeService(
      context.read<SecureStore>(),
      context.read<BiometricService>(),
      context.read<DownloadService>(),
      onLogout: () => context.read<SessionController>().logout(),
    );

    _prepare();
  }

  /// Seed the cookie + build document-start user scripts before the first load.
  Future<void> _prepare() async {
    final store = context.read<SecureStore>();
    final token = await store.readToken() ?? '';
    final userJson = await store.readUserJson() ?? '{}';
    final permsJson = await store.readPermissionsJson();
    final origin = AppConfig.appOrigin;

    // 1) Cookie first — the Next.js edge middleware gates routes off this cookie
    //    on the very first request, before React hydrates.
    await CookieManager.instance().setCookie(
      url: WebUri(AppConfig.appUrl),
      name: 'auth_token',
      value: token,
      path: '/',
      isSecure: AppConfig.appUri.scheme == 'https',
      sameSite: HTTPCookieSameSitePolicy.LAX,
      expiresDate:
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
    );

    // 2) Document-start scripts: seed localStorage + expose NativeBridge.
    _userScripts = [
      UserScript(
        source: BridgeScripts.authInjectionJs(
          token: token,
          userJson: userJson,
          permsJson: permsJson,
          origin: origin,
        ),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
      UserScript(
        source: BridgeScripts.bridgeShimJs(
          origin: origin,
          platform:
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        ),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
    ];

    final path = _session?.initialRoute ?? '/dashboard';
    _initialUrl = WebUri('${AppConfig.appUrl}$path');

    if (mounted) setState(() => _ready = true);
  }

  void _onIncomingRoute() {
    final route = _session?.incomingRoute.value;
    if (route == null || _controller == null) return;
    // Warm deep link / notification tap: let React route client-side (no reload).
    _bridge.dispatch(_controller!, 'deeplink', route);
    _session!.incomingRoute.value = null;
  }

  void _onConnectivityChanged() {
    final online = _connectivity?.online ?? true;
    if (online && _loadError) {
      _controller?.reload();
    }
    if (_controller != null) {
      _bridge.dispatch(_controller!, 'networkStatus', {'online': online});
    }
    setState(() {});
  }

  @override
  void dispose() {
    _session?.incomingRoute.removeListener(_onIncomingRoute);
    _connectivity?.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _loadError = false);
    if (_controller != null) {
      await _controller!.reload();
    } else {
      _prepare();
    }
  }

  bool get _offline => !(_connectivity?.online ?? true);

  @override
  Widget build(BuildContext context) {
    if (!_ready || _userScripts == null || _initialUrl == null) {
      return const Scaffold(
        backgroundColor: BrandColors.page,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_controller != null && await _controller!.canGoBack()) {
          _controller!.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: BrandColors.page,
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: _initialUrl),
                initialUserScripts:
                    UnmodifiableListView<UserScript>(_userScripts!),
                pullToRefreshController: _pullToRefresh,
                initialSettings: _settings(),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  _bridge.register(controller);
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) _pullToRefresh.endRefreshing();
                  setState(() => _progress = progress);
                },
                onLoadStop: (controller, url) async {
                  _pullToRefresh.endRefreshing();
                  setState(() => _firstLoadDone = true);
                },
                onReceivedError: (controller, request, error) {
                  _pullToRefresh.endRefreshing();
                  // Only surface errors for the main frame document.
                  if (request.isForMainFrame ?? false) {
                    setState(() => _loadError = true);
                  }
                },
                onPermissionRequest: (controller, request) async {
                  // The WebView can only hand camera/mic to React's getUserMedia
                  // if the *native* process holds the runtime permission first.
                  final granted =
                      await _ensureMediaPermissions(request.resources);
                  return PermissionResponse(
                    resources: request.resources,
                    action: granted
                        ? PermissionResponseAction.GRANT
                        : PermissionResponseAction.DENY,
                  );
                },
                onDownloadStartRequest: (controller, req) async {
                  await _download(req);
                },
                shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
              ),
              if (_progress < 100 && !_loadError)
                LinearProgressIndicator(
                  value: _progress / 100.0,
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  color: BrandColors.indigoHover,
                ),
              if (_loadError || _offline)
                Positioned.fill(
                  child: OfflineView(
                    onRetry: _retry,
                    message: _offline
                        ? "You're offline. Check your connection and try again."
                        : "Couldn't load the page. Please try again.",
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InAppWebViewSettings _settings() => InAppWebViewSettings(
        // Core
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        transparentBackground: true,
        supportZoom: false,
        // Media (camera/mic for React scanner; inline video)
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        iframeAllowFullscreen: true,
        // Security: HTTPS only, no mixed content (Android)
        mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
        // Storage (Android)
        thirdPartyCookiesEnabled: true,
        // File upload / access (Android)
        allowFileAccess: true,
        // Branding hook so the web app can detect the native shell via UA too
        applicationNameForUserAgent: 'BednBiteApp/1.0',
      );

  /// Ensure the native runtime camera/mic permission is held before letting the
  /// WebView grant it to web content. Declaring CAMERA in the manifest isn't
  /// enough on Android 6+ / iOS — getUserMedia stays blocked until the OS grant
  /// is in hand. Returns true only when every requested media resource is usable.
  Future<bool> _ensureMediaPermissions(
    List<PermissionResourceType> resources,
  ) async {
    final needCamera = resources.contains(PermissionResourceType.CAMERA) ||
        resources.contains(PermissionResourceType.CAMERA_AND_MICROPHONE);
    final needMic = resources.contains(PermissionResourceType.MICROPHONE) ||
        resources.contains(PermissionResourceType.CAMERA_AND_MICROPHONE);

    final wanted = <Permission>[
      if (needCamera) Permission.camera,
      if (needMic) Permission.microphone,
    ];
    // Non-media requests (clipboard, etc.) aren't OS-gated here — allow them.
    if (wanted.isEmpty) return true;

    final statuses = await wanted.request();
    final allGranted = statuses.values.every((s) => s.isGranted || s.isLimited);

    // Permanently denied: Android/iOS won't prompt again, so the only way back
    // is the system settings page — surface that instead of silently failing.
    if (!allGranted &&
        statuses.values.any((s) => s.isPermanentlyDenied) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Camera access is turned off. Enable it in Settings to scan.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return allGranted;
  }

  Future<void> _download(DownloadStartRequest req) async {
    final downloads = context.read<DownloadService>();
    try {
      await downloads.download(
        req.url.toString(),
        filename: req.suggestedFilename,
      );
    } catch (_) {/* notification/open failures are non-fatal */}
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;

    final scheme = uri.scheme.toLowerCase();

    // Non-http schemes (tel:, mailto:, whatsapp:, intent:) → hand to the OS.
    if (scheme != 'http' && scheme != 'https') {
      await _launchExternal(uri);
      return NavigationActionPolicy.CANCEL;
    }

    // Our origin: keep it in the WebView…
    if (uri.host == AppConfig.appUri.host) {
      // …but a full navigation to /login means the web session expired
      // (api.ts redirects there on 401). Hand off to native login.
      final isLogin = uri.path == '/login' || uri.path.startsWith('/login');
      if (isLogin && _firstLoadDone) {
        await context.read<SessionController>().logout();
        return NavigationActionPolicy.CANCEL;
      }
      return NavigationActionPolicy.ALLOW;
    }

    // Any other host (external link) → open in the system browser.
    if (action.isForMainFrame) {
      await _launchExternal(uri);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _launchExternal(WebUri uri) async {
    try {
      await launchUrl(Uri.parse(uri.toString()),
          mode: LaunchMode.externalApplication);
    } catch (_) {/* ignore unlaunchable URLs */}
  }
}
