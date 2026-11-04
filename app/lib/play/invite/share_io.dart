import 'package:flutter/services.dart';

/// Appli Android (téléphone) : menu de partage d'Android et ouverture des liens.
const _channel = MethodChannel('partybroc/share');

Future<bool> shareLink({required String title, required String text, required String url}) async {
  try {
    return await _channel.invokeMethod<bool>('share', {'title': title, 'text': '$text $url'}) ?? false;
  } catch (_) {
    return false;
  }
}

void openLink(String url) {
  _channel.invokeMethod<bool>('open', {'url': url}).catchError((_) => false);
}
