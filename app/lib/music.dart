import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Musique de fond de l'écran TV : « salon » au salon et au podium, « jeu » pendant les parties.
/// Salon : les morceaux salon1…salon5.ogg en lecture aléatoire (le suivant démarre tout seul,
/// jamais deux fois le même d'affilée). Jeu : jeu.ogg en boucle. Fichiers dans assets/music/
/// (musiques Mixkit, licence gratuite sans mention obligatoire).
class Music {
  Music._();
  static final instance = Music._();

  static const playlists = <String, List<String>>{
    'salon': ['salon1', 'salon2', 'salon3', 'salon4', 'salon5'],
    'jeu': ['jeu'],
  };

  final _player = AudioPlayer();
  final _rnd = Random();
  String? _want; // ambiance demandée ('salon' ou 'jeu')
  String? _playing; // ambiance réellement lancée
  String? _last; // dernier morceau joué (pour ne pas le rejouer tout de suite)
  bool muted = false;
  bool _ready = false;
  static const volume = 0.45;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      final p = await SharedPreferences.getInstance();
      muted = p.getBool('pb_muted') ?? false;
      await _player.setVolume(volume);
      // Fin d'un morceau du salon : le suivant, au hasard
      _player.onPlayerComplete.listen((_) {
        if (!muted && _playing != null && _playing == _want && playlists[_playing]!.length > 1) _start();
      });
    } catch (_) {}
  }

  /// Demande une piste ('salon' ou 'jeu'). Ne relance rien si c'est déjà elle.
  Future<void> play(String track) async {
    _want = track;
    if (muted || _playing == track) return;
    await _start();
  }

  Future<void> _start() async {
    final t = _want;
    if (t == null) return;
    final list = playlists[t] ?? [t];
    final choices = list.length > 1 ? list.where((x) => x != _last).toList() : list;
    final track = choices[_rnd.nextInt(choices.length)];
    try {
      await _player.stop();
      // Une seule piste (jeu) : en boucle ; une liste (salon) : on enchaîne à la fin
      await _player.setReleaseMode(list.length > 1 ? ReleaseMode.stop : ReleaseMode.loop);
      await _player.play(AssetSource('music/$track.ogg'), volume: volume);
      _playing = t;
      _last = track;
    } catch (_) {
      // Navigateur : la lecture automatique est bloquée tant qu'on n'a pas touché l'écran.
      _playing = null;
    }
  }

  /// À appeler au premier appui (clic, télécommande) : débloque le son dans un navigateur
  Future<void> unlock() async {
    if (!muted && _playing == null && _want != null) await _start();
  }

  /// Appli en arrière-plan : on coupe le son ; au retour on le remet
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (muted || _want == null) return;
    try {
      if (_playing == _want) {
        await _player.resume();
      } else {
        await _start();
      }
    } catch (_) {}
  }

  Future<bool> toggle() async {
    muted = !muted;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('pb_muted', muted);
    } catch (_) {}
    if (muted) {
      await _player.stop();
      _playing = null;
    } else {
      await _start();
    }
    return muted;
  }
}
