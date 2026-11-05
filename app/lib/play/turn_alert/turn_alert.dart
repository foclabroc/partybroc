import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../music.dart';
import 'vibrate_stub.dart' if (dart.library.js_interop) 'vibrate_web.dart';

/// « À toi de jouer ! » sur le téléphone : petite clochette (assets/sfx/tour.ogg) et vibration,
/// au moment où c'est au tour du joueur, dans tous les jeux au tour par tour
/// (l'état du téléphone `you.myTurn` passe à vrai). Réglage « Son et vibration à mon tour ».
class TurnAlert {
  TurnAlert._();
  static final instance = TurnAlert._();

  bool enabled = true;
  bool _was = false;
  String? _game;
  AudioPlayer? _player;

  /// À appeler à chaque état reçu du serveur
  void onState(String? gameId, Map<String, dynamic>? you) {
    final now = gameId != null && you?['myTurn'] == true;
    if (gameId != _game) {
      _game = gameId;
      _was = false;
    }
    if (now && !_was) ping();
    _was = now;
  }

  Future<void> ping() async {
    if (!enabled) return;
    turnVibrate();
    try {
      if (_player == null) {
        _player = AudioPlayer();
        await pbMixAudio(_player!);
        if (!kIsWeb) await _player!.setPlayerMode(PlayerMode.lowLatency);
      }
      await _player!.stop();
      await _player!.play(AssetSource('sfx/tour.ogg'), volume: 0.9);
    } catch (_) {}
  }
}
