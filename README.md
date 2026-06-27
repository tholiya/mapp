# App — Flutter Mobile Shell

A thin native Android + iOS shell around the existing App React app
(`../react`). Flutter owns native login, secure token storage, biometrics,
deep links, downloads and a JS bridge; **all business logic stays in React**,
hosted inside a WebView.

> Architecture, decisions and verification steps:
> `~/.claude/plans/piped-hatching-liskov.md`.

## How auth works (no React login screen)

1. User logs in **natively** → `POST {USER_SERVICE_URL}/user/api/v1/users/login`.
2. Token + user + permissions are stored in the **Keystore / Keychain**.
3. Before the WebView loads, the shell:
   - sets the **`auth_token` cookie** (so the Next.js edge middleware passes on
     the first request), and
   - injects `auth_token` / `auth_user` / `auth_permissions` into
     **localStorage** at document-start.
4. React's `AuthContext` + `lib/api.ts` find the session and boot straight to
   `/dashboard` — **zero React auth changes**.

## Configure (no secrets in the repo)

Pass your real origins at build/run time:

```bash
flutter run \
  --dart-define=APP_URL=https://app.example.com \
  --dart-define=USER_SERVICE_URL=https://api.example.com \
  --dart-define=DEEPLINK_SCHEME=example
```

| define | meaning |
|---|---|
| `APP_URL` | deployed React origin loaded in the WebView |
| `USER_SERVICE_URL` | user-service origin for the native login call |
| `DEEPLINK_SCHEME` | custom scheme (default `example`) |

Defaults live in [lib/config/app_config.dart](lib/config/app_config.dart).

## Run / build

```bash
flutter pub get
dart run flutter_launcher_icons          # app icons from assets/logo/logo_icon.png
dart run flutter_native_splash:create    # splash screen

flutter run --dart-define=APP_URL=... --dart-define=USER_SERVICE_URL=...
flutter build apk   --release --dart-define=APP_URL=... --dart-define=USER_SERVICE_URL=...
flutter build appbundle --release ...
flutter build ipa   --release ...
```

Quality gates:

```bash
flutter analyze   # currently: No issues found
flutter test
```

## Project layout

```
lib/
  config/app_config.dart         build-time origins (--dart-define)
  theme/app_theme.dart           example dark theme + wordmark gradient
  models/                        AuthUser, ApiException
  bridge/bridge_scripts.dart     document-start JS: auth seed + NativeBridge shim
  services/
    secure_store.dart            Keystore/Keychain
    auth_service.dart            native login/logout (envelope-aware)
    session_controller.dart      phase machine: splash -> login/lock -> web
    bridge_service.dart          React->Flutter handlers + Flutter->React events
    biometric_service.dart       local_auth (unlock + step-up)
    connectivity_service.dart    online/offline
    download_service.dart        download + open in native viewer
    deeplink_service.dart        custom scheme + universal links -> path
    notification_service.dart    local notifications
  screens/                       splash, login, lock, webview, offline_view
```

## JS bridge

The shell injects `window.NativeBridge` (feature-detect `isNative`). The web app
calls it via the optional helper `../react/lib/nativeBridge.ts`:

| React -> Flutter | Flutter -> React (CustomEvents) |
|---|---|
| `biometricAuth`, `download`, `openPdf`, `share`, `call`, `whatsapp`, `getToken`, `logout`, `setClipboard` | `native:deeplink`, `native:notificationClick`, `native:networkStatus`, `native:biometricResult`, `native:logout` |

To enable in-app deep-link routing without a reload, wire the helper near the
React root:

```ts
const router = useRouter();
useEffect(() => onNativeNavigate((path) => router.push(path)), [router]);
```

## Native config already applied

- **Android** (`android/app/src/main/AndroidManifest.xml`): INTERNET, CAMERA,
  RECORD_AUDIO, USE_BIOMETRIC, POST_NOTIFICATIONS; custom-scheme + App-Links
  intent filters; `usesCleartextTraffic=false`; `resizeableActivity` (tablets);
  url_launcher `<queries>`. `minSdk 23` + core-library desugaring
  (`android/app/build.gradle.kts`).
- **iOS** (`ios/Runner/Info.plist`): camera/mic/FaceID/photo usage strings;
  ATS `NSAllowsArbitraryLoads=false`; `CFBundleURLTypes` (example scheme);
  `LSApplicationQueriesSchemes`; iPad orientations retained.

## Before publishing — finish these

1. **Real domains:** set `APP_URL` / `USER_SERVICE_URL`, and replace
   `app.example.com` in the AndroidManifest App-Links filter.
2. **Universal Links (iOS):** add `applinks:app.example.com` to
   `Runner.entitlements` (Associated Domains capability) and host
   `/.well-known/apple-app-site-association`.
3. **App Links (Android):** host `/.well-known/assetlinks.json` with your
   signing-cert SHA-256 so `autoVerify` succeeds.
4. **Release signing (Android):** create an upload keystore, add
   `android/keystore.properties`, and point the `release` `signingConfig` at it
   (currently signs with the debug key so `--release` runs locally).
5. **App icons / splash:** the source art is `assets/logo/logo_icon.png`; run the
   two `dart run` generators above.

## Deferred / excluded (by decision)

- **QR scanner, document scanner** — excluded; React already does these in-WebView.
- **Refresh token** — not used; the 7-day JWT re-prompts native login on expiry
  (a full navigation to `/login` from the web triggers native logout).
- **Push notifications (FCM)** — deferred. The notification-tap -> deep-link
  navigation pipeline is already built; add an FCM plugin + a backend
  device-registration endpoint (e.g. `POST /user/api/v1/devices`) to finish it.
- **Forgot password** — the link opens the web `/login`; needs a backend
  password-reset endpoint to function end-to-end.
