import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

const _kinds = {
  'sprint': ('🏃', 'Sprint', 'Gauche, droite, gauche, droite… le plus vite possible !'),
  'haies': ('🚧', 'Course de haies', 'Quand une haie arrive, touche SAUTE ! Ratée = tu trébuches 1 seconde.'),
  'turbo': ('⚡', 'Haies et turbo', 'Saute les haies, et touche ⚡ quand il apparaît : 2 secondes à double vitesse !'),
};

String _secs(num ms) => '${(ms / 1000).toStringAsFixed(2).replaceAll('.', ',')} s';

List<int> _ints(Object? v) => [for (final x in (v as List?) ?? const []) (x as num).toInt()];
Map<String, int> _intMap(Object? v) => {for (final e in ((v as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()};

/// Course au tap sur la TV
class CrsTv extends StatelessWidget {
  const CrsTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  String get kind => live.s('kind') ?? 'sprint';

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🏃',
          title: 'Course au tap',
          sub: '${live.i('count')} courses',
          rules: const [
            'Tape GAUCHE puis DROITE en alternance sur ton téléphone pour courir.',
            'Deux fois le même côté ne compte pas. Saute les haies, prends les turbos !',
          ],
          live: live),
      'ready' => _ready(),
      'go' => _race(),
      'result' => _result(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: ph == 'go' ? 'race-${live.i('index')}' : '$ph-${live.i('index')}', child: body);
  }

  Widget _ready() {
    final (emoji, title, rule) = _kinds[kind] ?? _kinds['sprint']!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 50, 80, 50),
      child: Column(children: [
        Text('Course ${live.i('index') + 1} / ${live.i('count')}', style: Pb.t(44, weight: 600, color: Pb.muted)),
        Text('$emoji  $title', style: Pb.t(100, weight: 700)),
        const SizedBox(height: 10),
        Text(rule, textAlign: TextAlign.center, style: Pb.t(44, color: Pb.yellow, height: 1.25)),
        Expanded(child: Center(child: _lanes(preview: true))),
        Countdown(
          endsIn: live.endsIn,
          duration: live.duration,
          builder: (_, _, s) => Text(s > 0 ? 'Départ dans $s…' : 'Partez !', style: Pb.t(64, weight: 700, color: Pb.pink)),
        ),
      ]),
    );
  }

  Widget _race() {
    final (emoji, title, _) = _kinds[kind] ?? _kinds['sprint']!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 40, 60, 40),
      child: Column(children: [
        Row(children: [
          Text('$emoji  $title', style: Pb.t(48, weight: 700)),
          const SizedBox(width: 24),
          Text('Course ${live.i('index') + 1} / ${live.i('count')}', style: Pb.t(36, color: Pb.muted)),
          const Spacer(),
          RepaintBoundary(child: TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 100)),
        ]),
        const SizedBox(height: 20),
        Expanded(child: _lanes()),
      ]),
    );
  }

  /// Une piste par joueur connecté : haies, turbos, avatar qui avance, arrivée
  Widget _lanes({bool preview = false}) {
    final players = room.players.where((p) => p.connected).toList();
    final length = live.i('length', 1);
    final hurdles = _ints(live['hurdles']);
    final turbos = _ints(live['turbos']);
    final pos = _intMap(live['pos']);
    final stumbles = _intMap(live['stumbles']);
    final finish = _intMap(live['finish']);
    final arrived = finish.entries.toList()..sort((a, b) => a.value - b.value);
    return LayoutBuilder(builder: (context, c) {
      final n = players.length.clamp(1, 15);
      final h = preview ? ((c.maxHeight - 8 * (n - 1)) / n).clamp(40.0, 72.0) : ((c.maxHeight - 8 * (n - 1)) / n).clamp(44.0, 120.0);
      final av = h * .82;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final p in players)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: h,
              child: Row(children: [
                SizedBox(
                  width: 250,
                  child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t((h * .38).clamp(22, 40), weight: 600)),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, lc) {
                    final w = lc.maxWidth - av;
                    double x(int step) => w * (step / length).clamp(0, 1);
                    final f = finish[p.pid];
                    final place = f == null ? null : arrived.indexWhere((e) => e.key == p.pid) + 1;
                    final st = stumbles[p.pid] ?? 0;
                    return Stack(clipBehavior: Clip.none, children: [
                      // la piste
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Pb.playerColor(p.color).withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(h / 2),
                          ),
                        ),
                      ),
                      // ligne d'arrivée
                      Positioned(right: av / 2 - 6, top: 0, bottom: 0, child: Container(width: 12, color: Colors.white.withValues(alpha: .7))),
                      for (final hu in hurdles)
                        Positioned(
                          left: x(hu) + av / 2 - 5,
                          top: h * .18,
                          bottom: h * .18,
                          child: Container(width: 10, decoration: BoxDecoration(color: const Color(0xFFFF8A3D), borderRadius: BorderRadius.circular(4))),
                        ),
                      for (final t in turbos)
                        Positioned(left: x(t) + av / 2 - h * .2, top: h * .25, child: Text('⚡', style: TextStyle(fontSize: h * .38))),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        left: x(pos[p.pid] ?? 0),
                        top: (h - av) / 2,
                        child: PbAvatar(size: av, emoji: p.emoji, color: p.color, photoPath: p.photo),
                      ),
                      if (f != null)
                        Positioned(
                          right: av + 20,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              '${switch (place) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '$place.' }} ${_secs(f)}',
                              style: Pb.t((h * .4).clamp(22, 42), weight: 700, color: Pb.yellow),
                            ),
                          ),
                        )
                      else if (st > 0 && !preview)
                        Positioned(
                          right: av + 20,
                          top: 0,
                          bottom: 0,
                          child: Center(child: Text('💥×$st', style: Pb.t((h * .34).clamp(20, 36), weight: 600, color: Pb.muted))),
                        ),
                    ]);
                  }),
                ),
              ]),
            ),
          ),
      ]);
    });
  }

  Widget _result() {
    final order = live.maps('order');
    final (emoji, title, _) = _kinds[kind] ?? _kinds['sprint']!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(160, 60, 160, 50),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$emoji  $title : arrivée', style: Pb.t(70, weight: 700)),
        const SizedBox(height: 30),
        if (order.isEmpty) Text('Personne n’a couru 😴', style: Pb.t(50, color: Pb.muted)),
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
                Text(o['ms'] != null ? _secs(o['ms'] as num) : 'pas arrivé', style: Pb.t(46, weight: 700, color: o['ms'] != null ? Pb.cyan : Pb.muted)),
                const SizedBox(width: 40),
                SizedBox(width: 180, child: Text('+${o['pts']}', textAlign: TextAlign.right, style: Pb.t(46, weight: 700, color: Pb.green))),
              ]),
            ),
      ]),
    );
  }
}

/// Course au tap sur le téléphone. Le téléphone compte ses pas (GAUCHE/DROITE en
/// alternance), gère les sauts et le turbo, et envoie sa position 5 fois par seconde.
class CrsPlay extends StatefulWidget {
  const CrsPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<CrsPlay> createState() => _CrsPlayState();
}

class _CrsPlayState extends State<CrsPlay> {
  final _watch = Stopwatch();
  String _key = '';
  int _n = 0; // pas faits
  int _last = -1; // dernier pied : 0 gauche, 1 droite
  int _nextH = 0; // prochaine haie
  final _jumped = <int>{}; // haies où on a sauté à temps
  int _stumbles = 0;
  int _nextT = 0; // prochain turbo
  DateTime _stumbleUntil = DateTime(2000);
  DateTime _turboOffer = DateTime(2000); // bouton ⚡ visible jusqu'à
  DateTime _boostUntil = DateTime(2000);
  bool _finished = false;
  int _sentN = -1;
  Timer? _tick;
  bool _wrongFoot = false;

  Map<String, dynamic> get live => widget.live;
  int get k => live.i('index');
  int get length => live.i('length', 1);
  List<int> get hurdles => _ints(live['hurdles']);
  List<int> get turbos => _ints(live['turbos']);

  @override
  void initState() {
    super.initState();
    _track();
  }

  @override
  void didUpdateWidget(CrsPlay old) {
    super.didUpdateWidget(old);
    _track();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // Nouvelle course : tout remettre à zéro ; départ : chrono et envois réguliers
  void _track() {
    final key = '${live.phase}-$k';
    if (key == _key) return;
    _key = key;
    if (live.phase == 'ready') {
      _n = 0;
      _last = -1;
      _nextH = 0;
      _nextT = 0;
      _jumped.clear();
      _stumbles = 0;
      _finished = false;
      _sentN = -1;
      _stumbleUntil = _turboOffer = _boostUntil = DateTime(2000);
    }
    _tick?.cancel();
    if (live.phase == 'go') {
      _watch
        ..reset()
        ..start();
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _flush();
        if (mounted) setState(() {}); // fin de chute, du turbo…
      });
    } else {
      _flush();
    }
  }

  void _flush({bool force = false}) {
    if (!force && (_n == _sentN || _finished)) return;
    _sentN = _n;
    widget.send({
      't': 'game_msg',
      'm': {'t': 'crs', 'k': k, 'n': _n, 's': _stumbles, if (_finished) 'ms': _watch.elapsedMilliseconds},
    });
  }

  bool get _stumbling => DateTime.now().isBefore(_stumbleUntil);
  bool get _boosting => DateTime.now().isBefore(_boostUntil);
  bool get _canJump => _nextH < hurdles.length && !_jumped.contains(_nextH) && hurdles[_nextH] - _n <= 5 && !_stumbling;
  bool get _turboVisible => DateTime.now().isBefore(_turboOffer) && !_boosting;

  void _foot(int f) {
    if (live.phase != 'go' || _finished || _stumbling) return;
    if (f == _last) {
      // Même pied deux fois : ne compte pas
      HapticFeedback.lightImpact();
      setState(() => _wrongFoot = true);
      return;
    }
    _last = f;
    _wrongFoot = false;
    HapticFeedback.selectionClick();
    var n = _n + (_boosting ? 2 : 1);
    final hs = hurdles;
    if (_nextH < hs.length && n >= hs[_nextH]) {
      if (_jumped.contains(_nextH)) {
        _nextH++;
      } else {
        // Haie ratée : on trébuche dessus 1 seconde
        n = hs[_nextH];
        _nextH++;
        _stumbles++;
        _stumbleUntil = DateTime.now().add(const Duration(seconds: 1));
        HapticFeedback.heavyImpact();
      }
    }
    final ts = turbos;
    if (_nextT < ts.length && n >= ts[_nextT]) {
      _nextT++;
      _turboOffer = DateTime.now().add(const Duration(milliseconds: 1500));
    }
    _n = n.clamp(0, length);
    if (_n >= length) {
      _finished = true;
      _watch.stop();
      HapticFeedback.heavyImpact();
      _flush(force: true);
    }
    setState(() {});
  }

  void _jump() {
    if (!_canJump) return;
    HapticFeedback.mediumImpact();
    setState(() => _jumped.add(_nextH));
  }

  void _turbo() {
    if (!_turboVisible) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _boostUntil = DateTime.now().add(const Duration(seconds: 2));
      _turboOffer = DateTime(2000);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final you = widget.you;
    final (emoji, title, rule) = _kinds[live.s('kind')] ?? _kinds['sprint']!;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🏃', title: 'Course au tap', sub: 'Pose tes deux pouces : gauche, droite, gauche, droite…'),
      'ready' => PhoneCenter(emoji: emoji, title: title, sub: rule),
      'go' => _finished || you.yi('finish') != null
          ? PhoneCenter(emoji: '🏁', title: 'Arrivé !', color: Pb.green, sub: _secs(_watch.elapsedMilliseconds), extra: const Text('Regarde la TV 📺'))
          : _run(),
      'result' => _result(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-$k-${_finished || you.yi('finish') != null}', isHost: widget.isHost, phase: ph, send: widget.send, child: body);
  }

  Widget _run() {
    final hs = hurdles;
    final stumbling = _stumbling;
    final boosting = _boosting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 12),
      child: Column(children: [
        // Ma piste en petit : haies, turbos, ma position
        SizedBox(
          height: 34,
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth - 30;
            double x(int s) => w * (s / length).clamp(0, 1);
            return Stack(children: [
              Positioned.fill(child: Container(decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(17)))),
              for (var i = 0; i < hs.length; i++)
                Positioned(
                  left: x(hs[i]) + 12,
                  top: 6,
                  bottom: 6,
                  child: Container(width: 6, color: i < _nextH ? Pb.muted.withValues(alpha: .4) : const Color(0xFFFF8A3D)),
                ),
              for (final t in turbos) Positioned(left: x(t) + 6, top: 4, child: const Text('⚡', style: TextStyle(fontSize: 18))),
              Positioned(left: x(_n), top: 2, child: const Text('🏃', style: TextStyle(fontSize: 24))),
              const Positioned(right: 4, top: 4, child: Text('🏁', style: TextStyle(fontSize: 20))),
            ]);
          }),
        ),
        const SizedBox(height: 6),
        Text('${(_n * 100 / length).round()} %', style: Pb.t(18, weight: 700, color: Pb.muted)),
        // Zone du milieu : SAUTE, ⚡, ou consigne
        Expanded(
          child: Center(
            child: stumbling
                ? Text('💥 Aïe !', style: Pb.t(52, weight: 700, color: Pb.red))
                : _canJump
                    ? _actionButton('SAUTE !', const Color(0xFFFF8A3D), _jump)
                    : _turboVisible
                        ? _actionButton('⚡ TURBO', Pb.yellow, _turbo, dark: true)
                        : Text(
                            boosting
                                ? '⚡ Double vitesse !'
                                : _wrongFoot
                                    ? 'Alterne gauche / droite !'
                                    : (_nextH < hs.length && _jumped.contains(_nextH) ? 'Hop ! 🦘' : 'Cours !'),
                            style: Pb.t(30, weight: 700, color: boosting ? Pb.yellow : (_wrongFoot ? Pb.red : Pb.text)),
                          ),
          ),
        ),
        // Les deux pieds
        SizedBox(
          height: 260,
          child: Row(children: [
            Expanded(child: _footButton(0, 'GAUCHE', stumbling)),
            const SizedBox(width: 12),
            Expanded(child: _footButton(1, 'DROITE', stumbling)),
          ]),
        ),
      ]),
    );
  }

  Widget _footButton(int f, String label, bool off) {
    final next = _last != f; // le pied attendu est mis en avant
    final color = f == 0 ? Pb.cyan : Pb.pink;
    return Listener(
      onPointerDown: (_) => _foot(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: off ? Pb.card : (next ? color : color.withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🦶', style: TextStyle(fontSize: 44)),
          Text(label, style: Pb.t(24, weight: 700, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap, {bool dark = false}) => Listener(
        onPointerDown: (_) => onTap(),
        child: Container(
          width: double.infinity,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: color.withValues(alpha: .6), blurRadius: 24)],
          ),
          child: Text(label, style: Pb.t(44, weight: 700, color: dark ? Pb.bg : Colors.white)),
        ),
      );

  Widget _result() {
    final you = widget.you;
    final place = you.yi('place');
    final g = you.yi('gain') ?? 0;
    final f = you.yi('finish');
    return PhoneCenter(
      emoji: switch (place) { null => '😴', _ when f == null => '🐢', 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '👏' },
      title: place == null ? 'Pas de pas comptés' : (f == null ? 'Pas arrivé' : '${place == 1 ? '1er' : '${place}e'} !'),
      color: place == 1 ? Pb.yellow : Pb.text,
      extra: Column(children: [
        if (f != null) Text(_secs(f), style: Pb.t(26, weight: 700, color: Pb.cyan)),
        if (g > 0) Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)),
      ]),
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}
