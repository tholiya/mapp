import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'notification_service.dart';
import 'secure_store.dart';

/// Downloads PDFs / invoices / reports / images to app storage, then opens them
/// in the native viewer. Auth header is attached from secure storage so files
/// behind `Authorization: Bearer` (booking-service `/uploads`, PDFs) work.
class DownloadService {
  final SecureStore _store;
  final NotificationService _notifications;
  final Dio _dio;

  DownloadService(this._store, this._notifications, {Dio? dio})
      : _dio = dio ?? Dio();

  Future<void> download(String url, {String? filename}) async {
    final token = await _store.readToken();
    final dir = await _targetDir();
    final name = _safeName(filename ?? _nameFromUrl(url));
    final path = '${dir.path}/$name';

    await _dio.download(
      url,
      path,
      options: Options(
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    await _notifications.show(
      title: 'Download complete',
      body: name,
    );
    await OpenFilex.open(path);
  }

  Future<Directory> _targetDir() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    return getApplicationDocumentsDirectory();
  }

  String _nameFromUrl(String url) {
    final seg = Uri.parse(url).pathSegments;
    final last = seg.isNotEmpty ? seg.last : '';
    return last.isEmpty ? 'download_${DateTime.now().millisecondsSinceEpoch}' : last;
  }

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
