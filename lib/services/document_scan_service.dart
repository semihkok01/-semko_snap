import 'dart:io';

import 'package:flutter/services.dart';

class DocumentScanService {
  static const MethodChannel _channel = MethodChannel(
    'semkosnap/document_scanner',
  );

  Future<String?> scanSinglePage() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      return await _channel.invokeMethod<String>('startScan');
    } on PlatformException catch (exception) {
      if (exception.code == 'cancelled') {
        return null;
      }

      throw Exception(
        exception.message ?? 'Google-Dokumentenscanner ist nicht verfügbar.',
      );
    }
  }
}

