import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Navigateur : navigator.vibrate (Android ; ignoré par l'iPhone)
Future<void> mngBuzz(bool ok) async {
  try {
    web.window.navigator.vibrate((ok ? [35] : [70, 60, 70]).map((e) => e.toJS).toList().toJS);
  } catch (_) {}
}
