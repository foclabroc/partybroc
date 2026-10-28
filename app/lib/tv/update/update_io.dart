import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Où l'appli TV va chercher ses mises à jour : la release « tv-latest » du dépôt,
/// remplie automatiquement par GitHub (apk.yml) à chaque nouvelle version.
const _base = String.fromEnvironment('PB_UPDATE_BASE',
    defaultValue: 'https://github.com/foclabroc/partybroc/releases/download/tv-latest');
const _channel = MethodChannel('partybroc/update');

class TvUpdate {
  TvUpdate(this.versionCode, this.versionName, this.notes);
  final int versionCode;
  final String versionName;
  final String notes;
}

/// L'appli n'a pas encore le droit d'installer des applis (« Sources inconnues »)
class NeedInstallPermission implements Exception {}

Future<Map<String, dynamic>> _info() async =>
    Map<String, dynamic>.from(await _channel.invokeMethod('info') as Map);

HttpClient _client() => HttpClient()..connectionTimeout = const Duration(seconds: 15);

/// Une version plus récente existe ? (null sinon, ou si le réseau ne répond pas)
Future<TvUpdate?> checkTvUpdate() async {
  if (!Platform.isAndroid) return null;
  final client = _client();
  try {
    final info = await _info();
    final local = (info['versionCode'] as num).toInt();
    final req = await client.getUrl(Uri.parse('$_base/tv-version.json?t=${DateTime.now().millisecondsSinceEpoch}'));
    final res = await req.close();
    if (res.statusCode != 200) return null;
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final remote = (j['versionCode'] as num).toInt();
    if (remote <= local) return null;
    return TvUpdate(remote, j['versionName'] as String? ?? '', j['notes'] as String? ?? '');
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Télécharge l'APK puis ouvre l'installateur Android (l'utilisateur confirme « Installer »)
Future<void> installTvUpdate(TvUpdate u, void Function(double progress) onProgress) async {
  final info = await _info();
  if (info['canInstall'] != true) throw NeedInstallPermission();
  final dir = Directory('${info['cacheDir']}/update');
  await dir.create(recursive: true);
  final file = File('${dir.path}/partybroc-tv-${u.versionCode}.apk');
  final client = _client();
  try {
    final res = await (await client.getUrl(Uri.parse('$_base/partybroc-tv.apk'))).close();
    if (res.statusCode != 200) throw HttpException('Téléchargement impossible (${res.statusCode})');
    final total = res.contentLength;
    var got = 0;
    final sink = file.openWrite();
    await for (final chunk in res) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) onProgress(got / total);
    }
    await sink.close();
  } finally {
    client.close();
  }
  final ok = await _channel.invokeMethod<bool>('install', {'path': file.path});
  if (ok != true) throw Exception('L’installateur Android n’a pas pu s’ouvrir');
}

Future<bool> openInstallSettings() async => (await _channel.invokeMethod<bool>('openInstallSettings')) ?? false;
