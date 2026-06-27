import 'dart:convert';

/// JavaScript injected into the WebView at document-start (before the React
/// bundle runs). Two scripts:
///   1. [authInjectionJs] — seeds localStorage so AuthContext hydrates and
///      api.ts finds the token. Guarded to the app origin.
///   2. [bridgeShimJs] — exposes `window.NativeBridge` so React can call native
///      capabilities. Each method proxies to a flutter_inappwebview handler.
class BridgeScripts {
  /// Seeds the three localStorage keys React reads (auth_token / auth_user /
  /// auth_permissions). [userJson] and [permsJson] are already-stringified JSON.
  /// All values are JSON-encoded again so quotes/specials embed safely.
  static String authInjectionJs({
    required String token,
    required String userJson,
    required String permsJson,
    required String origin,
  }) {
    return '''
(function () {
  try {
    if (location.origin !== ${jsonEncode(origin)}) return;
    localStorage.setItem('auth_token', ${jsonEncode(token)});
    localStorage.setItem('auth_user', ${jsonEncode(userJson)});
    localStorage.setItem('auth_permissions', ${jsonEncode(permsJson)});
  } catch (e) {}
})();
''';
  }

  /// Bridge shim. Methods return Promises that resolve with the native handler's
  /// result (biometricAuth/getToken resolve a value; others resolve when done).
  static String bridgeShimJs({
    required String origin,
    required String platform,
  }) {
    return '''
(function () {
  try {
    if (location.origin !== ${jsonEncode(origin)}) return;
    if (window.NativeBridge && window.NativeBridge.isNative) return;
    function call(name, arg) {
      return window.flutter_inappwebview.callHandler(name, arg);
    }
    window.NativeBridge = {
      isNative: true,
      platform: ${jsonEncode(platform)},
      biometricAuth: function (reason) { return call('biometricAuth', reason || ''); },
      download: function (url, filename) { return call('download', { url: url, filename: filename || null }); },
      share: function (data) { return call('share', data || {}); },
      call: function (phone) { return call('callPhone', String(phone || '')); },
      whatsapp: function (phone, text) { return call('whatsapp', { phone: String(phone || ''), text: text || '' }); },
      openPdf: function (url) { return call('openPdf', String(url || '')); },
      getToken: function () { return call('getToken'); },
      logout: function () { return call('logout'); },
      setClipboard: function (text) { return call('setClipboard', String(text || '')); }
    };
    try { window.dispatchEvent(new Event('nativebridgeready')); } catch (e) {}
  } catch (e) {}
})();
''';
  }

  /// Builds a Flutter→React event dispatch. React subscribes via
  /// `window.addEventListener('native:<name>', e => e.detail)`.
  static String dispatchEventJs(String name, Object? detail) {
    final payload = jsonEncode(detail);
    return "try{window.dispatchEvent(new CustomEvent(${jsonEncode('native:$name')},{detail:$payload}));}catch(e){}";
  }
}
