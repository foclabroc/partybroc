import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 'done' (déjà sur l'écran d'accueil), 'prompt' (Android peut installer d'un appui),
/// 'ios' (menu Partager), 'none' (menu du navigateur). Voir web/flutter_bootstrap.js.
String installKind() {
  try {
    final r = globalContext.callMethod<JSAny?>('pbInstallKind'.toJS);
    return (r as JSString?)?.toDart ?? 'none';
  } catch (_) {
    return 'none';
  }
}

Future<bool> install() async {
  try {
    final p = globalContext.callMethod<JSPromise<JSBoolean>>('pbInstall'.toJS);
    return (await p.toDart).toDart;
  } catch (_) {
    return false;
  }
}
