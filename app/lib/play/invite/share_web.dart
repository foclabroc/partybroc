import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Menu de partage du téléphone (SMS, Messenger, WhatsApp…), via navigator.share.
/// Renvoie false s'il n'existe pas (PC, vieux navigateur) : on propose alors nos boutons.
Future<bool> shareLink({required String title, required String text, required String url}) async {
  try {
    final nav = web.window.navigator;
    if (!nav.has('share')) return false;
    await nav.share(web.ShareData(title: title, text: text, url: url)).toDart;
    return true;
  } catch (e) {
    // Annulé par le joueur : le menu s'est bien ouvert, rien d'autre à faire
    final s = e.toString();
    return s.contains('AbortError') || s.contains('abort');
  }
}

/// Ouvre un lien (sms:, WhatsApp, Messenger…)
void openLink(String url) {
  try {
    web.window.location.href = url;
  } catch (_) {}
}
