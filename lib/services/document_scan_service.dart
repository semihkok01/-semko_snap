import 'dart:io';

import 'package:flutter/services.dart';

class DocumentScanService {
  static const MethodChannel _channel = MethodChannel(
    'semkosnap/document_scanner',
  );

  Future<String?> scanSinglePage() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return null;
    }

    try {
      return await _channel.invokeMethod<String>('startScan');
    } on PlatformException catch (exception) {
      if (exception.code == 'cancelled') {
        return null;
      }

      throw Exception(_localizedPlatformMessage(exception));
    }
  }

  String _localizedPlatformMessage(PlatformException exception) {
    switch (exception.code) {
      case 'busy':
        return 'Der Dokumentenscanner ist bereits geöffnet.';
      case 'unavailable':
        return 'Der Dokumentenscanner ist auf diesem Gerät derzeit nicht verfügbar.';
      case 'scan_failed':
        return exception.message?.trim().isNotEmpty == true
            ? exception.message!.trim()
            : 'Der Beleg konnte nicht gescannt werden.';
      default:
        return exception.message?.trim().isNotEmpty == true
            ? exception.message!.trim()
            : 'Dokumentenscanner ist nicht verfügbar.';
    }
  }
}
