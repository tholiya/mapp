/// Build-time configuration. Override per environment with --dart-define, e.g.
///
///   flutter run \
///     --dart-define=APP_URL=https://app.bednbite.com \
///     --dart-define=USER_SERVICE_URL=https://api.bednbite.com
///
/// Nothing secret lives here — these are public origins only.
class AppConfig {
  /// Deployed React (Next.js) app origin loaded inside the WebView.
  static const String appUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://app.bednbite.com',
  );

  /// user-service base origin used by the native login call.
  /// The login path is appended: `$userServiceUrl/user/api/v1/users/login`.
  static const String userServiceUrl = String.fromEnvironment(
    'USER_SERVICE_URL',
    defaultValue: 'https://api.bednbite.com',
  );

  /// Custom deep-link scheme: myapp://booking/123
  static const String deepLinkScheme = String.fromEnvironment(
    'DEEPLINK_SCHEME',
    defaultValue: 'bednbite',
  );

  /// Origin used to scope localStorage injection + cookie. Derived from [appUrl].
  static Uri get appUri => Uri.parse(appUrl);

  /// Host-only origin string used by the injected user script's origin guard.
  static String get appOrigin {
    final u = appUri;
    final port = u.hasPort ? ':${u.port}' : '';
    return '${u.scheme}://${u.host}$port';
  }
}
