// lib/web_helper.dart
import 'package:flutter/foundation.dart' show kIsWeb;

// Import the actual implementation classes directly
import 'web_stub.dart';
import 'web_impl.dart';

class WebHelper {
  static void openAuthWindow(String url) {
    if (kIsWeb) {
      WebImpl.openAuthWindow(url);
    } else {
      WebStub.openAuthWindow(url);
    }
  }

  static void setupAuthListener(Function callback) {
    if (kIsWeb) {
      WebImpl.setupAuthListener(callback);
    } else {
      WebStub.setupAuthListener(callback);
    }
  }
}