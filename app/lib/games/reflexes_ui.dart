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
  'cible': ('🎯', 'Cibles', 'Touche les 5 cibles qui apparaissent sur ton téléphone, le plus vite possible !'),
  'fleches': ('⬅️', 'Flèches', 'Touche la direction de chaque flèche. Une erreur = 1 seconde de pénalité !'),
  'intrus': ('🔎', 'L’intrus', 'Un seul emoji est différent des autres sur ton téléphone : trouve-le !'),
  'chrono': ('⏱️', 'Chrono à l’aveugle', 'Le chrono disparaît vite : arrête-le pile au temps demandé !'),
};

const _arrows = ['⬅️', '➡️', '⬆️', '⬇️'];
const _arrowIcons = [Icons.arrow_back_rounded, Icons.arrow_forward_rounded, Icons.arrow_upward_rounded, Icons.arrow_downward_rounded];

String _sec(num ms, [int digits = 3]) => '${(ms / 1000).toStringAsFixed(digits).replaceAll('.', ',')} s';

String _metric(Map<String, dynamic> o, String type) => switch (type) {
      'taps' => '${o['n']} taps',
      'chrono' => '${_sec(o['stopped'] as num? ?? 0, 2)} (écart ${_sec(o['rt'] as num, 2)})',
      'fleches' => '${_sec(o['rt'] as num)}${(o['e'] as num? ?? 0) > 0 ? ' (${o['e']} erreur${(o['e'] as num) > 1 ? 's' : ''})' : ''}',
      _ => _sec(o['rt'] as num),
    };

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
      case 'cible' || 'fleches' || 'intrus':
        center = Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_info[type]!.$1, style: const TextStyle(fontSize: 200)),
          Text('Sur ton téléphone, vite !', style: Pb.t(80, weight: 700)),
        ]);
      case 'chrono':
        center = Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Arrête le chrono à', style: Pb.t(70, weight: 600, color: Pb.muted)),
          Text(_sec(live.i('target'), 0), style: Pb.t(260, weight: 700, color: Pb.yellow)),
          Text('…sans le voir ! 🙈', style: Pb.t(60, weight: 600)),
        ]);
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
    // jusqu'à 15 lignes : plus serrées au-delà de 8 joueurs
    final big = players.length <= 8;
    final av = big ? 74.0 : (players.length > 12 ? 44.0 : 54.0);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final p in players)
        Padding(
          padding: EdgeInsets.symmetric(vertical: big ? 8 : 3),
          child: Row(children: [
            SizedBox(width: 300, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(big ? 40 : 30, weight: 600))),
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) {
                  final f = (taps[p.pid] ?? 0) / best;
                  return Stack(children: [
                    Container(height: av, decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(40))),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      left: (c.maxWidth - av) * f,
                      child: PbAvatar(size: av, emoji: p.emoji, color: p.color, photoPath: p.photo),
                    ),
                  ]);
                },
              ),
            ),
            SizedBox(width: 140, child: Text('${taps[p.pid] ?? 0}', textAlign: TextAlign.right, style: Pb.t(big ? 48 : 34, weight: 700))),
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
          if (type == 'chrono') TvChip(text: 'Objectif : ${_sec(live.i('target'), 0)}', color: Pb.yellow, size: 40),
          if (type == 'intrus') TvChip(text: 'L’intrus : ${live.s('odd') ?? ''} parmi les ${live.s('base') ?? ''}', color: Pb.yellow, size: 40),
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
  int _step = 0; // cibles touchées / flèches réussies
  int _errors = 0; // flèches : erreurs
  Timer? _chronoTimer; // chrono : affichage du début

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
      _step = 0;
      _errors = 0;
    }
    _chronoTimer?.cancel();
    if (live.phase == 'go' && type == 'chrono') {
      // le chrono s'affiche 1,5 s puis disparaît
      _chronoTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
        if (!mounted) return t.cancel();
        setState(() {});
        if (_watch.elapsedMilliseconds > 1500) t.cancel();
      });
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
    _chronoTimer?.cancel();
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
              child: _grid4([
                  for (var c = 0; c < 4; c++)
                    Listener(
                      onPointerDown: (_) => _answer({'c': c}),
                      child: Container(decoration: BoxDecoration(color: rfxColors[c], borderRadius: BorderRadius.circular(24))),
                    ),
                ]),
            ),
          ]),
        );
      case 'cible':
        if (done) return const PhoneCenter(emoji: '🎯', title: 'Toutes touchées !', sub: 'Regarde la TV');
        if (live.phase != 'go') return const PhoneCenter(emoji: '🎯', title: 'Prépare-toi…');
        final targets = [for (final t in (live['targets'] as List?) ?? const []) [for (final v in t as List) (v as num).toDouble()]];
        if (_step >= targets.length) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 44, 12, 12),
          child: LayoutBuilder(builder: (_, c) {
            const size = 96.0;
            final t = targets[_step];
            return Stack(children: [
              Positioned.fill(child: Container(decoration: BoxDecoration(color: Pb.card.withValues(alpha: .5), borderRadius: BorderRadius.circular(24)))),
              Positioned(top: 10, left: 0, right: 0, child: Text('${_step + 1} / ${targets.length}', textAlign: TextAlign.center, style: Pb.t(20, weight: 700, color: Pb.muted))),
              Positioned(
                left: t[0] * (c.maxWidth - size),
                top: t[1] * (c.maxHeight - size),
                child: Listener(
                  onPointerDown: (_) {
                    HapticFeedback.mediumImpact();
                    setState(() => _step++);
                    if (_step >= targets.length) _answer({});
                  },
                  child: const SizedBox(width: size, height: size, child: Center(child: Text('🎯', style: TextStyle(fontSize: 80)))),
                ),
              ),
            ]);
          }),
        );
      case 'fleches':
        if (done) return const PhoneCenter(emoji: '✅', title: 'Fini !', sub: 'Regarde la TV');
        if (live.phase != 'go') return const PhoneCenter(emoji: '⬅️', title: 'Prépare-toi…');
        final arrows = [for (final a in (live['arrows'] as List?) ?? const []) (a as num).toInt()];
        if (_step >= arrows.length) return const SizedBox.shrink();
        Widget btn(int d) => Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Listener(
                  onPointerDown: (_) {
                    if (d == arrows[_step]) {
                      HapticFeedback.selectionClick();
                      setState(() => _step++);
                      if (_step >= arrows.length) _answer({'e': _errors});
                    } else {
                      HapticFeedback.heavyImpact();
                      setState(() => _errors++);
                    }
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Pb.answerColors[d], borderRadius: BorderRadius.circular(24)),
                    child: Icon(_arrowIcons[d], size: 64, color: Colors.white),
                  ),
                ),
              ),
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 44, 12, 12),
          child: Column(children: [
            Text('${_step + 1} / ${arrows.length}${_errors > 0 ? '   ❌ $_errors' : ''}', style: Pb.t(20, weight: 700, color: Pb.muted)),
            Expanded(child: Center(child: Text(_arrows[arrows[_step]], style: const TextStyle(fontSize: 130)))),
            SizedBox(height: 120, child: Row(children: [btn(0), btn(2)])),
            SizedBox(height: 120, child: Row(children: [btn(3), btn(1)])),
          ]),
        );
      case 'intrus':
        if (done) return const PhoneCenter(emoji: '✅', title: 'Réponse envoyée', sub: 'Regarde la TV');
        if (live.phase != 'go') return const PhoneCenter(emoji: '🔎', title: 'Prépare-toi…');
        final pos = live.i('pos'), n = live.i('size', 20);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 44, 12, 12),
          child: Column(children: [
            Text('Lequel est différent ?', style: Pb.t(22, weight: 700)),
            const SizedBox(height: 10),
            // Toute la grille doit tenir à l'écran (sinon l'intrus peut être caché en bas)
            Expanded(
              child: LayoutBuilder(builder: (_, c) {
                final rows = (n / 4).ceil();
                final cell = c.maxWidth / 4, h = c.maxHeight / rows;
                return GridView.count(
                  crossAxisCount: 4,
                  childAspectRatio: cell / h,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < n; i++)
                      Listener(
                        onPointerDown: (_) => _answer({'c': i}),
                        child: Center(
                          child: Text(i == pos ? live.s('odd') ?? '' : live.s('base') ?? '',
                              style: TextStyle(fontSize: (h < cell ? h : cell) * .55)),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ]),
        );
      case 'chrono':
        if (done) return const PhoneCenter(emoji: '⏱️', title: 'Chrono arrêté !', sub: 'Regarde la TV');
        if (live.phase != 'go') return PhoneCenter(emoji: '⏱️', title: 'Objectif : ${_sec(live.i('target'), 0)}', sub: 'Le chrono va disparaître…');
        final ms = _watch.elapsedMilliseconds;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
          child: Column(children: [
            Text('Objectif : ${_sec(live.i('target'), 0)}', style: Pb.t(26, weight: 700, color: Pb.yellow)),
            const SizedBox(height: 10),
            Text(ms < 1500 ? _sec(ms, 2) : '?,?? s', style: Pb.t(64, weight: 700)),
            const SizedBox(height: 16),
            Expanded(child: _bigButton(color: Pb.pink, label: 'STOP', onDown: () => _answer({}))),
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
              child: _grid4([
                  for (var i = 0; i < opts.length; i++)
                    Listener(
                      onPointerDown: (_) => _answer({'c': opts[i]}),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Pb.answerColors[i % 4], borderRadius: BorderRadius.circular(24)),
                        child: Text('${opts[i]}', style: Pb.t(64, weight: 700, color: Colors.white)),
                      ),
                    ),
                ]),
            ),
          ]),
        );
    }
    return const SizedBox.shrink();
  }

  // 4 cases en 2 × 2 qui remplissent toujours la place (une grille fixe dépassait de
  // l'écran sur les petits téléphones)
  static Widget _grid4(List<Widget> c) {
    Widget row(int i) => Expanded(
          child: Row(children: [
            for (var j = i; j < i + 2; j++)
              Expanded(child: Padding(padding: const EdgeInsets.all(6), child: j < c.length ? c[j] : const SizedBox())),
          ]),
        );
    return Column(children: [row(0), row(2)]);
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
