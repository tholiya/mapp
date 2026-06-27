import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks online/offline state. The WebView shell listens and swaps in a native
/// offline screen on loss, then retries the load when connectivity returns.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _conn = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _online = true;
  bool get online => _online;

  Future<void> start() async {
    final initial = await _conn.checkConnectivity();
    _online = _isOnline(initial);
    _sub = _conn.onConnectivityChanged.listen((results) {
      final next = _isOnline(results);
      if (next != _online) {
        _online = next;
        notifyListeners();
      }
    });
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
