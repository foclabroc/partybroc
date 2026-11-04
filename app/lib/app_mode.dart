import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Appli Android « PartyBroc » pour le téléphone du joueur (compilée avec --flavor phone).
/// Sur le web et dans PartyBroc TV : false.
bool get isPhoneApp => !kIsWeb && appFlavor == 'phone';

/// L'APK de l'appli téléphone, publié par GitHub (apk.yml) à chaque nouvelle version.
const kAndroidApkUrl = 'https://github.com/foclabroc/partybroc/releases/download/tv-latest/partybroc.apk';

/// Code du salon contenu dans un lien (…/play?code=ABCD), un QR ou un texte (« abcd »).
String? codeFromLink(String? s) {
  if (s == null) return null;
  s = s.trim();
  if (RegExp(r'^[A-Za-z]{4,12}$').hasMatch(s)) return s.toUpperCase();
  final c = Uri.tryParse(s)?.queryParameters['code']?.trim();
  if (c == null || !RegExp(r'^[A-Za-z]{4,12}$').hasMatch(c)) return null;
  return c.toUpperCase();
}
