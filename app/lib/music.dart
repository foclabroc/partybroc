import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Musique de fond de l'écran TV : « salon » au salon et au podium, « jeu » pendant les parties.
/// Les fichiers sont dans assets/music/ (boucles .ogg, remplaçables).
class Music {
  Music._();
  static final instance = Music._();

  final _player = AudioPlayer();
  String? _want; // piste demandée
  String? _playing; // piste réellement lancée
  bool muted = false;
  bool _ready = false;
  static const volume = 0.45;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      final p = await SharedPreferences.getInstance();
      muted = p.getBool('pb_muted') ?? false;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);
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
    try {
      await _player.stop();
      await _player.play(AssetSource('music/$t.ogg'), volume: volume);
      _playing = t;
    } catch (_) {
      // Navigateur : la lecture automatique est bloquée tant qu'on n'a pas touché l'écran.
      _playing = null;
    }
  }

  /// À appeler au premier appui (clic, télécommande) : débloque le son dans un navigateur
  Future<void> unlock() async {
    if (!muted && _playing == null && _want != null) await _start();
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
