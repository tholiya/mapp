import 'dart:async';

import 'package:app_links/app_links.dart';

import '../config/app_config.dart';

/// Resolves incoming deep links to an in-app path the WebView should open.
/// Handles both:
///   `bednbite://booking/123`               (custom scheme)
///   `https://app.example.com/booking/123`  (App Links / Universal Links)
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Returns the path (e.g. "/booking/123") for a deep link the app was
  /// launched from, or null if launched normally.
  Future<String?> initialPath() async {
    final uri = await _appLinks.getInitialLink();
    return uri == null ? null : _toPath(uri);
  }

  /// Streams paths for deep links received while the app is already running.
  void listen(void Function(String path) onPath) {
    _sub = _appLinks.uriLinkStream.listen((uri) {
      final p = _toPath(uri);
      if (p != null) onPath(p);
    });
  }

  String? _toPath(Uri uri) {
    // Custom scheme: bednbite://booking/123 → host="booking", path="/123"
    if (uri.scheme == AppConfig.deepLinkScheme) {
      final path = '/${uri.host}${uri.path}'.replaceAll(RegExp(r'/+'), '/');
      return _withQuery(path, uri);
    }
    // https links to our app origin: take the path as-is.
    if (uri.host == AppConfig.appUri.host) {
      final path = uri.path.isEmpty ? '/' : uri.path;
      return _withQuery(path, uri);
    }
    return null;
  }

  String _withQuery(String path, Uri uri) =>
      uri.hasQuery ? '$path?${uri.query}' : path;

  void dispose() => _sub?.cancel();
}
