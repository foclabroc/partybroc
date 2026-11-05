import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Navigateur : navigator.vibrate (Android ; ignoré par l'iPhone)
Future<void> turnVibrate() async {
  try {
    web.window.navigator.vibrate([220, 120, 220].map((e) => e.toJS).toList().toJS);
  } catch (_) {}
}
