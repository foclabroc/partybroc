import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music.dart';

/// Animateur vocal : la TV lit les questions et annonce les résultats (synthèse vocale
/// d'Android, ou du navigateur). La musique baisse pendant qu'il parle.
class Voice {
  Voice._();
  static final instance = Voice._();

  final _tts = FlutterTts();
  bool muted = false;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      final p = await SharedPreferences.getInstance();
      muted = p.getBool('pb_voice_muted') ?? false;
      await _tts.setLanguage('fr-FR');
      // Android : 0,5 = vitesse normale ; navigateur : 1 = normale
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
      await _tts.setVolume(1);
      await _tts.setPitch(1.05);
      _tts.setStartHandler(() => Music.instance.duck(true));
      _tts.setCompletionHandler(() => Music.instance.duck(false));
      _tts.setCancelHandler(() => Music.instance.duck(false));
      _tts.setErrorHandler((_) => Music.instance.duck(false));
    } catch (_) {}
  }

  /// Lit un texte (coupe le précédent)
  Future<void> say(String text) async {
    if (muted || !_ready) return;
    final t = clean(text);
    if (t.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(t);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    Music.instance.duck(false);
  }

  Future<bool> toggle() async {
    muted = !muted;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('pb_voice_muted', muted);
    } catch (_) {}
    if (muted) {
      await stop();
    } else {
      await say('Je suis l’animateur de PartyBroc !');
    }
    return muted;
  }

  /// Texte prêt à lire : sans emojis, symboles de calcul en mots
  static String clean(String s) {
    var t = s
        .replaceAll('×', ' fois ')
        .replaceAll('÷', ' divisé par ')
        .replaceAll('−', ' moins ')
        .replaceAll('²', ' au carré')
        .replaceAll(' % de ', ' pour cent de ')
        .replaceAll(RegExp(r'_{2,}'), ' … ')
        .replaceAll('«', '')
        .replaceAll('»', '');
    // emojis et symboles : ignorés (sinon la voix les nomme en anglais ou se tait)
    t = String.fromCharCodes(t.runes.map((r) =>
        (r >= 0x1F000 && r <= 0x1FAFF) || (r >= 0x2600 && r <= 0x27BF) || (r >= 0x2B00 && r <= 0x2BFF) || r == 0xFE0F || r == 0x200D ? 0x20 : r));
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 4,50 € → « 4 euros 50 »
  static String euros(num v) {
    final e = v.floor();
    final c = ((v - e) * 100).round();
    return c == 0 ? '$e euros' : '$e euros $c';
  }
}

/// Ce que dit l'animateur, d'après l'état du salon (une seule fois par étape)
class VoiceDirector {
  String? _key;

  void onRoom(Map<String, dynamic> room) {
    final v = Voice.instance;
    if (v.muted) return;
    final live = room['game'] as Map<String, dynamic>?;
    final so = room['soiree'] as Map<String, dynamic>?;
    final players = {for (final p in (room['players'] as List? ?? const [])) (p as Map)['pid']: p['name'] as String? ?? ''};
    String name(Object? pid) => players[pid] ?? '';

    // Entre deux jeux d'une soirée, et à la fin
    if (live == null) {
      if (so != null && (so['step'] == 'interlude' || so['step'] == 'final')) {
        final key = 'soiree-${so['index']}-${so['step']}';
        if (key == _key) return;
        _key = key;
        final rk = (so['ranking'] as List? ?? const []).cast<Map>();
        final first = rk.where((r) => r['rank'] == 1).map((r) => name(r['pid'])).where((n) => n.isNotEmpty).toList();
        final who = first.join(' et ');
        if (so['step'] == 'final') {
          v.say(first.isEmpty ? 'Fin de la soirée ! Bravo à tous !' : '$who remporte la soirée ! Bravo à tous !');
        } else {
          v.say(first.isEmpty ? 'Classement de la soirée.' : 'Classement de la soirée. En tête : $who !');
        }
      } else {
        _key = null;
      }
      return;
    }

    final id = live['id'] as String? ?? '';
    final phase = live['phase'] as String? ?? '';
    final key = '$id-${live['index'] ?? ''}-${live['turn'] ?? ''}-$phase';
    if (key == _key) return;
    _key = key;
    final text = _line(room, live, id, phase, name);
    if (text != null && text.isNotEmpty) v.say(text);
  }

  String? _line(Map<String, dynamic> room, Map<String, dynamic> live, String id, String phase, String Function(Object?) name) {
    String s(String k) => live[k] as String? ?? '';
    List<String> list(String k) => [for (final x in (live[k] as List? ?? const [])) '$x'];

    if (phase == 'intro') {
      final g = (room['games'] as List? ?? const []).cast<Map>().where((g) => g['id'] == id).firstOrNull;
      return g == null ? null : '${g['title']} ! C’est parti !';
    }
    if (phase == 'podium') {
      final rk = (live['ranking'] as List? ?? const []).cast<Map>();
      final first = rk.where((r) => r['rank'] == 1 && (r['score'] as num? ?? 0) > 0).map((r) => name(r['pid'])).toList();
      return first.isEmpty ? 'Fin de la partie !' : 'Bravo ${first.join(' et ')} !';
    }
    switch (id) {
      case 'quiz':
        if (phase == 'question') return s('question');
        if (phase == 'reveal') {
          final a = list('answers');
          final c = (live['correct'] as num?)?.toInt();
          return c != null && c < a.length ? 'La bonne réponse : ${a[c]}' : null;
        }
      case 'quidenous':
        if (phase == 'vote') return 'Qui est le plus susceptible de ${s('prompt')} ?';
      case 'droles':
        if (phase == 'write') return s('prompt');
        if (phase == 'vote') return 'Votez pour la réponse la plus drôle !';
      case 'dessin':
        if (phase == 'draw') return '${name(live['drawer'])} dessine !';
        if (phase == 'reveal') return 'C’était : ${s('word')}';
      case 'justeprix':
        if (phase == 'ask') return 'Combien coûte : ${s('name')}, ${s('detail')} ?';
        if (phase == 'reveal' && live['price'] is num) return 'Le prix moyen : ${Voice.euros(live['price'] as num)}';
      case 'quiadit':
        if (phase == 'write') return 'Répondez en secret sur votre téléphone !';
        if (phase == 'ask') return '${s('prompt')} : ${s('text')}. Qui a écrit ça ?';
        if (phase == 'reveal') return 'C’était ${name(live['author'])} !';
      case 'photoroulette':
        if (phase == 'pick') return 'Choisissez vos photos sur votre téléphone !';
        if (phase == 'ask') return 'À qui est cette photo ?';
        if (phase == 'reveal') return 'C’était à ${name(live['owner'])} !';
      case 'calcul':
        if (phase == 'ask') return '${s('expr')} ?';
        if (phase == 'reveal') return 'Résultat : ${live['value']}';
      case 'memoire':
        if (phase == 'show') return 'Mémorisez bien !';
        if (phase == 'ask') return s('say');
      case 'zoom':
        if (phase == 'ask') return 'Qu’est-ce que c’est ?';
        if (phase == 'reveal') {
          final a = list('choices');
          final c = (live['correct'] as num?)?.toInt();
          return c != null && c < a.length ? 'C’était : ${a[c]}' : null;
        }
      case 'survie':
        if (phase == 'ask') return '${s('statement')} Vrai ou faux ?';
        if (phase == 'reveal') return '${live['truth'] == true ? 'Vrai !' : 'Faux !'} ${s('explain')}';
      case 'reflexes':
        if (phase == 'ready') {
          const names = {
            'feu': 'Feu vert ! Attendez le vert.',
            'taps': 'Marathon de taps !',
            'couleur': 'Bonne couleur ! Touchez la couleur de l’encre.',
            'compte': 'Compte vite !',
            'cible': 'Cibles !',
            'fleches': 'Flèches ! Attention aux erreurs.',
            'intrus': 'Trouvez l’intrus !',
            'chrono': 'Chrono à l’aveugle !',
          };
          final t = names[s('type')];
          if (t == null) return null;
          final target = (live['target'] as num?)?.toInt();
          return s('type') == 'chrono' && target != null ? '$t Arrêtez-le à ${target ~/ 1000} secondes.' : t;
        }
      case 'petitbac':
        if (phase == 'write') return 'Lettre ${s('letter')} ! ${list('categories').join(', ')}.';
        if (phase == 'check') return 'On vérifie les réponses !';
    }
    return null;
  }
}
