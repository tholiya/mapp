import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bridge/bridge_scripts.dart';
import 'biometric_service.dart';
import 'download_service.dart';
import 'secure_store.dart';

/// Registers the React→Flutter handlers backing `window.NativeBridge`, and
/// provides Flutter→React event dispatch (deep links, notification clicks,
/// network status, logout).
class BridgeService {
  final SecureStore _store;
  final BiometricService _biometric;
  final DownloadService _downloads;

  /// Invoked when React calls NativeBridge.logout().
  final Future<void> Function() onLogout;

  BridgeService(
    this._store,
    this._biometric,
    this._downloads, {
    required this.onLogout,
  });

  /// Wire all handlers onto a freshly created controller.
  void register(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'biometricAuth',
      callback: (args) async {
        final reason = args.isNotEmpty ? args.first?.toString() ?? '' : '';
        final result = await _biometric.authenticate(reason);
        return {'status': result.name}; // success | failed | unavailable
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'download',
      callback: (args) async {
        final m = _firstMap(args);
        final url = m['url']?.toString();
        if (url == null || url.isEmpty) return {'ok': false};
        try {
          await _downloads.download(url, filename: m['filename']?.toString());
          return {'ok': true};
        } catch (e) {
          return {'ok': false, 'error': e.toString()};
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'openPdf',
      callback: (args) async {
        final url = args.isNotEmpty ? args.first?.toString() : null;
        if (url == null || url.isEmpty) return {'ok': false};
        try {
          await _downloads.download(url);
          return {'ok': true};
        } catch (e) {
          return {'ok': false, 'error': e.toString()};
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'share',
      callback: (args) async {
        final m = _firstMap(args);
        final text = m['text']?.toString() ?? m['url']?.toString() ?? '';
        final subject = m['title']?.toString();
        if (text.isEmpty) return {'ok': false};
        await Share.share(text, subject: subject);
        return {'ok': true};
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'callPhone',
      callback: (args) async {
        final phone = args.isNotEmpty ? args.first?.toString() ?? '' : '';
        return _launch(Uri(scheme: 'tel', path: phone));
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'whatsapp',
      callback: (args) async {
        final m = _firstMap(args);
        final phone = (m['phone']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        final text = m['text']?.toString() ?? '';
        final uri = Uri.parse(
            'https://wa.me/$phone${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');
        return _launch(uri);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'getToken',
      callback: (args) async => {'token': await _store.readToken()},
    );

    controller.addJavaScriptHandler(
      handlerName: 'setClipboard',
      callback: (args) async {
        final text = args.isNotEmpty ? args.first?.toString() ?? '' : '';
        await Clipboard.setData(ClipboardData(text: text));
        return {'ok': true};
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'logout',
      callback: (args) async {
        await onLogout();
        return {'ok': true};
      },
    );
  }

  /// Flutter → React: dispatch a `native:<name>` CustomEvent with [detail].
  Future<void> dispatch(
    InAppWebViewController controller,
    String name,
    Object? detail,
  ) async {
    await controller.evaluateJavascript(
      source: BridgeScripts.dispatchEventJs(name, detail),
    );
  }

  Future<Map<String, dynamic>> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return {'ok': ok};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _firstMap(List<dynamic> args) {
    if (args.isNotEmpty && args.first is Map) {
      return Map<String, dynamic>.from(args.first as Map);
    }
    return <String, dynamic>{};
  }
}
