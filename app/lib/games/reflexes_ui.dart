import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

/// Couleurs de l'épreuve « bonne couleur » (même ordre que le serveur)
const rfxColors = <Color>[Color(0xFFFF3B3B), Color(0xFF3B82FF), Color(0xFFFFD23F), Color(0xFF2FD36B)];
const rfxNames = ['ROUGE', 'BLEU', 'JAUNE', 'VERT'];

const _info = {
  'feu': ('🚦', 'Feu vert !', 'Attends que ça passe au VERT, puis tape le plus vite possible. Trop tôt = faux départ !'),
  'taps': ('👆', 'Marathon de taps', 'Tape sur ton écran le plus de fois possible pendant 8 secondes !'),
  'couleur': ('🎨', 'Bonne couleur', 'Touche la couleur de l’ENCRE du mot, pas ce qui est écrit !'),
  'compte': ('🔢', 'Compte vite', 'Compte les emojis qui s’affichent sur la TV, puis choisis le bon nombre.'),
};

String _metric(Map<String, dynamic> o, String type) =>
    type == 'taps' ? '${o['n']} taps' : '${((o['rt'] as num) / 1000).toStringAsFixed(3).replaceAll('.', ',')} s';

/// Course de réflexes sur la TV
class RfxTv extends StatelessWidget {
  const RfxTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  String get type => live.s('type') ?? '';

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '⚡',
          title: 'Course de réflexes',
          sub: '${live.i('count')} épreuves',
          rules: const ['Des épreuves éclair : regarde la TV, joue sur ton téléphone.', 'Le plus rapide marque 500 points !'],
          live: live),
      'ready' => _ready(),
      'wait' || 'go' || 'show' => _play(),
      'result' => _result(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '$ph-${live.i('index')}', child: body);
  }

  Widget _ready() {
    final (emoji, title, rule) = _info[type] ?? ('⚡', '', '');
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Épreuve ${live.i('index') + 1} / ${live.i('count')}', style: Pb.t(44, weight: 600, color: Pb.muted)),
        Text(emoji, style: const TextStyle(fontSize: 170)),
        Text(title, style: Pb.t(110, weight: 700)),
        const SizedBox(height: 24),
        SizedBox(width: 1400, child: Text(rule, textAlign: TextAlign.center, style: Pb.t(48, color: Pb.yellow, height: 1.25))),
        const SizedBox(height: 50),
        TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 120),
      ]),
    );
  }

  Widget _play() {
    final done = {...live.pids('done'), ...live.pids('falseStart')};
    Widget center;
    switch (type) {
      case 'feu':
        final go = live.phase == 'go';
        center = Container(
          width: 620,
          height: 620,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: go ? const Color(0xFF2FD36B) : const Color(0xFFFF3B3B),
            boxShadow: [BoxShadow(color: (go ? const Color(0xFF2FD36B) : const Color(0xFFFF3B3B)).withValues(alpha: .6), blurRadius: 120)],
          ),
          child: Text(go ? 'TAPEZ !' : 'Attendez…', style: Pb.t(110, weight: 700, color: Colors.white)),
        );
      case 'taps':
        center = _race();
      case 'couleur':
        final word = live.i('word', -1), ink = live.i('ink', -1);
        center = word < 0
            ? const SizedBox.shrink()
            : Text(rfxNames[word], style: Pb.t(300, weight: 700, color: rfxColors[ink]));
      case 'compte':
        center = live.phase == 'show' ? _emojiGrid(live.s('emoji') ?? '⭐', _cells()) : _countAsk();
      default:
        center = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 50, 80, 50),
      child: Column(children: [
        Row(children: [
          Text('${_info[type]?.$1 ?? ''}  ${_info[type]?.$2 ?? ''}', style: Pb.t(44, weight: 700)),
          const Spacer(),
          if (live.phase == 'go' && type != 'feu') TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 100),
        ]),
        Expanded(child: Center(child: center)),
        if (type != 'taps') SizedBox(height: 90, child: TvWhoDone(room: room, done: done, label: 'ont joué')),
      ]),
    );
  }

  List<int> _cells() => [for (final c in (live['cells'] as List?) ?? const []) (c as num).toInt()];

  Widget _emojiGrid(String emoji, List<int> cells) {
    return SizedBox(
      width: 1500,
      height: 760,
      child: GridView.count(
        crossAxisCount: 6,
        childAspectRatio: (1500 / 6) / (760 / 4),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 24; i++)
            Center(child: cells.contains(i) ? Text(emoji, style: const TextStyle(fontSize: 120)) : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _countAsk() => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Combien y en avait-il ?', style: Pb.t(100, weight: 700)),
        const SizedBox(height: 20),
        Text('Réponds sur ton téléphone !', style: Pb.t(50, color: Pb.muted)),
      ]);

  Widget _race() {
    final taps = {for (final e in ((live['taps'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()};
    final players = room.players.where((p) => p.connected).toList();
    final best = [1, ...taps.values].reduce((a, b) => a > b ? a : b);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final p in players)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(width: 300, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(40, weight: 600))),
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) {
                  final f = (taps[p.pid] ?? 0) / best;
                  return Stack(children: [
                    Container(height: 74, decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(40))),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      left: (c.maxWidth - 74) * f,
                      child: PbAvatar(size: 74, emoji: p.emoji, color: p.color, photoPath: p.photo),
                    ),
                  ]);
                },
              ),
            ),
            SizedBox(width: 140, child: Text('${taps[p.pid] ?? 0}', textAlign: TextAlign.right, style: Pb.t(48, weight: 700))),
          ]),
        ),
    ]);
  }

  Widget _result() {
    final order = live.maps('order');
    final falses = live.pids('falseStart');
    return Padding(
      padding: const EdgeInsets.fromLTRB(160, 60, 160, 50),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${_info[type]?.$1 ?? ''}  Résultats', style: Pb.t(70, weight: 700)),
          const Spacer(),
          if (type == 'compte') TvChip(text: 'Il y en avait ${live.i('answer')} ${live.s('emoji') ?? ''}', color: Pb.yellow, size: 40),
          if (type == 'couleur' && live.i('ink', -1) >= 0)
            TvChip(text: 'Il fallait : ${rfxNames[live.i('ink')].toLowerCase()}', color: rfxColors[live.i('ink')], size: 40),
        ]),
        const SizedBox(height: 30),
        if (order.isEmpty) Text('Personne n’a réussi cette épreuve 😅', style: Pb.t(50, color: Pb.muted)),
        for (final o in order.take(8))
          if (room.player(o['pid'] as String) case final p?)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                SizedBox(
                  width: 90,
                  child: Text(switch (o['place']) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '${o['place']}' }, style: Pb.t(56, weight: 700)),
                ),
                PbAvatar(size: 80, emoji: p.emoji, color: p.color, photoPath: p.photo),
                const SizedBox(width: 20),
                Expanded(child: Text(p.name, style: Pb.t(46, weight: 600))),
                Text(_metric(o, type), style: Pb.t(46, weight: 700, color: Pb.cyan)),
                const SizedBox(width: 40),
                SizedBox(width: 180, child: Text('+${o['pts']}', textAlign: TextAlign.right, style: Pb.t(46, weight: 700, color: Pb.green))),
              ]),
            ),
        if (falses.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('🚫 Faux départ : ${falses.map((f) => room.player(f)?.name ?? '?').join(', ')}', style: Pb.t(38, color: Pb.red)),
        ],
      ]),
    );
  }
}

/// Course de réflexes sur le téléphone. Le temps de réaction est mesuré ici,
/// depuis l'apparition du signal sur CET écran (le réseau ne compte pas).
class RfxPlay extends StatefulWidget {
  const RfxPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<RfxPlay> createState() => _RfxPlayState();
}

class _RfxPlayState extends State<RfxPlay> {
  final _watch = Stopwatch();
  String _goKey = '';
  int _taps = 0;
  int _sentTaps = -1;
  Timer? _tapTimer;
  bool _sent = false; // déjà répondu à cette épreuve (en attendant la confirmation du serveur)

  Map<String, dynamic> get live => widget.live;
  String get type => live.s('type') ?? '';
  int get k => live.i('index');

  @override
  void initState() {
    super.initState();
    _track();
  }

  @override
  void didUpdateWidget(RfxPlay old) {
    super.didUpdateWidget(old);
    _track();
  }

  // Le chrono démarre quand la phase « go » de l'épreuve apparaît ici
  void _track() {
    final key = '${live.phase}-$k';
    if (key == _goKey) return;
    _goKey = key;
    if (live.phase == 'ready') {
      _sent = false;
      _taps = 0;
      _sentTaps = -1;
    }
    if (live.phase == 'go') {
      _watch
        ..reset()
        ..start();
      if (type == 'taps') {
        _tapTimer?.cancel();
        _tapTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _flushTaps());
      }
    } else {
      _flushTaps();
      _tapTimer?.cancel();
      _tapTimer = null;
    }
  }

  void _flushTaps() {
    if (type != 'taps' || _taps == _sentTaps) return;
    _sentTaps = _taps;
    _msg({'n': _taps});
  }

  void _msg(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': {'t': 'rfx', 'k': k, ...m}});

  void _answer(Map<String, dynamic> extra) {
    if (_sent) return;
    HapticFeedback.heavyImpact();
    _sent = true;
    _msg({'rt': _watch.elapsedMilliseconds, ...extra});
    setState(() {});
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final you = widget.you;
    final done = _sent || you.yb('done');
    final (emoji, title, rule) = _info[type] ?? ('⚡', '', '');
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '⚡', title: 'Course de réflexes', sub: 'Garde le doigt prêt !'),
      'ready' => PhoneCenter(emoji: emoji, title: title, sub: rule),
      'wait' || 'go' || 'show' => _play(done),
      'result' => _result(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-$k', isHost: widget.isHost, phase: ph, send: widget.send, child: body);
  }

  Widget _play(bool done) {
    final you = widget.you;
    switch (type) {
      case 'feu':
        if (you.yb('falseStart')) return const PhoneCenter(emoji: '🚫', title: 'Faux départ !', sub: 'Il fallait attendre le vert…', color: Pb.red);
        if (done) return const PhoneCenter(emoji: '✅', title: 'Touché !', sub: 'Regarde la TV');
        final go = live.phase == 'go';
        return _bigButton(
          color: go ? const Color(0xFF2FD36B) : const Color(0xFFFF3B3B),
          label: go ? 'TAPE !' : 'Attends le vert…',
          onDown: () => _answer({}), // avant le vert, le serveur compte un faux départ
        );
      case 'taps':
        if (live.phase != 'go') return const PhoneCenter(emoji: '👆', title: 'Prépare tes doigts…');
        return _bigButton(
          color: Pb.pink,
          label: 'TAPE !\n$_taps',
          onDown: () {
            HapticFeedback.selectionClick();
            setState(() => _taps++);
          },
        );
      case 'couleur':
        if (done) return const PhoneCenter(emoji: '✅', title: 'Réponse envoyée', sub: 'Regarde la TV');
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
          child: Column(children: [
            Text('La couleur de l’ENCRE !', style: Pb.t(22, weight: 700)),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var c = 0; c < 4; c++)
                    Listener(
                      onPointerDown: (_) => _answer({'c': c}),
                      child: Container(decoration: BoxDecoration(color: rfxColors[c], borderRadius: BorderRadius.circular(24))),
                    ),
                ],
              ),
            ),
          ]),
        );
      case 'compte':
        if (live.phase == 'show') return const PhoneCenter(emoji: '👀', title: 'Compte sur la TV !');
        if (done) return const PhoneCenter(emoji: '✅', title: 'Réponse envoyée', sub: 'Regarde la TV');
        final opts = [for (final o in (live['options'] as List?) ?? const []) (o as num).toInt()];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
          child: Column(children: [
            Text('Combien ?', style: Pb.t(26, weight: 700)),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < opts.length; i++)
                    Listener(
                      onPointerDown: (_) => _answer({'c': opts[i]}),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Pb.answerColors[i % 4], borderRadius: BorderRadius.circular(24)),
                        child: Text('${opts[i]}', style: Pb.t(64, weight: 700, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        );
    }
    return const SizedBox.shrink();
  }

  // Bouton plein écran qui réagit dès l'appui (pas au relâchement)
  Widget _bigButton({required Color color, required String label, required VoidCallback onDown}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
      child: Listener(
        onPointerDown: (_) => onDown(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(32)),
          child: Text(label, textAlign: TextAlign.center, style: Pb.t(54, weight: 700, color: Colors.white, height: 1.1)),
        ),
      ),
    );
  }

  Widget _result() {
    final you = widget.you;
    final place = you.yi('place');
    final res = you?['result'] as Map<String, dynamic>?;
    if (you.yb('falseStart')) return const PhoneCenter(emoji: '🚫', title: 'Faux départ !', color: Pb.red);
    if (place == null) {
      return PhoneCenter(
        emoji: '😬',
        title: res != null && res['ok'] == false ? 'Mauvaise réponse' : 'Raté !',
        sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
      );
    }
    return PhoneCenter(
      emoji: switch (place) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '👏' },
      title: '${place == 1 ? '1er' : '${place}e'} !',
      color: place == 1 ? Pb.yellow : Pb.text,
      extra: Column(children: [
        if (res != null) Text(_metric(res, type), style: Pb.t(26, weight: 700, color: Pb.cyan)),
        Text('+${Pb.pts(you.yi('gain') ?? 0)}', style: Pb.t(46, weight: 700, color: Pb.green)),
      ]),
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}
