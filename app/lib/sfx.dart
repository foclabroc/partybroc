import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bruitages de l'écran TV (assets/sfx/*.ogg, fabriqués par tools/bruitages.py,
/// remplaçables par d'autres .ogg du même nom). Indépendants de la musique,
/// avec leur propre bouton « Bruitages ».
class Sfx {
  Sfx._();
  static final instance = Sfx._();

  static const names = ['pop', 'tick', 'whoosh', 'ding', 'buzz', 'fanfare', 'boom', 'applause'];
  static const volume = 0.8;

  // Quelques lecteurs en tourniquet : deux sons peuvent se chevaucher (feu d'artifice…)
  final _players = <AudioPlayer>[];
  int _next = 0;
  bool muted = false;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      final p = await SharedPreferences.getInstance();
      muted = p.getBool('pb_sfx_muted') ?? false;
      for (var i = 0; i < 4; i++) {
        final a = AudioPlayer();
        await a.setReleaseMode(ReleaseMode.stop);
        // Android : lecteur « basse latence » pour les sons courts
        if (!kIsWeb) await a.setPlayerMode(PlayerMode.lowLatency);
        _players.add(a);
      }
    } catch (_) {}
  }

  /// Joue un bruitage (sans jamais bloquer ni lever d'erreur)
  void play(String name, {double vol = 1}) {
    if (muted || _players.isEmpty) return;
    final a = _players[_next];
    _next = (_next + 1) % _players.length;
    unawaited(() async {
      try {
        await a.stop();
        await a.play(AssetSource('sfx/$name.ogg'), volume: volume * vol);
      } catch (_) {
        // navigateur : son bloqué tant qu'on n'a pas touché l'écran
      }
    }());
  }

  Future<bool> toggle() async {
    muted = !muted;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('pb_sfx_muted', muted);
    } catch (_) {}
    if (!muted) play('pop');
    return muted;
  }
}

/// Déclenche les bruitages d'après l'état du salon reçu par la TV :
/// arrivée d'un joueur, nouvelle question, 3 dernières secondes, révélation, élimination, podium.
class SfxDirector {
  String? _phaseKey;
  int _players = -1;
  final _ticks = <Timer>[];
  Timer? _show;

  static const _askPhases = {'question', 'ask', 'vote', 'write', 'draw', 'go'};

  void onRoom(Map<String, dynamic> room) {
    final players = (room['players'] as List?)?.length ?? 0;
    final live = room['game'] as Map<String, dynamic>?;
    // Un joueur de plus au salon
    if (live == null && _players >= 0 && players > _players) Sfx.instance.play('pop');
    _players = players;

    final phase = live?['phase'] as String?;
    final key = live == null ? null : '${live['id']}-${live['index'] ?? live['turn'] ?? ''}-$phase';
    if (key == _phaseKey) return;
    _phaseKey = key;
    _clearTicks();
    if (live == null || phase == null) return;

    final endsIn = (live['endsIn'] as num?)?.toInt() ?? 0;
    if (_askPhases.contains(phase)) {
      Sfx.instance.play('whoosh', vol: .7);
      // tic-tac des 3 dernières secondes
      for (final s in [3, 2, 1]) {
        final at = endsIn - s * 1000;
        if (at > 300) _ticks.add(Timer(Duration(milliseconds: at), () => Sfx.instance.play('tick')));
      }
    } else if (phase == 'reveal' || phase == 'result') {
      final out = (live['out'] as List?) ?? const [];
      Sfx.instance.play(out.isNotEmpty ? 'buzz' : 'ding');
    } else if (phase == 'podium') {
      _celebrate();
    }
  }

  // Podium : fanfare, feu d'artifice, applaudissements
  void _celebrate() {
    Sfx.instance.play('fanfare');
    for (final (ms, v) in [(1600, .9), (2600, .7), (3300, .8), (4400, .6), (5600, .7)]) {
      _ticks.add(Timer(Duration(milliseconds: ms), () => Sfx.instance.play('boom', vol: v)));
    }
    _ticks.add(Timer(const Duration(milliseconds: 2200), () => Sfx.instance.play('applause', vol: .8)));
  }

  void _clearTicks() {
    for (final t in _ticks) {
      t.cancel();
    }
    _ticks.clear();
    _show?.cancel();
  }

  void dispose() => _clearTicks();
}
