import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

// =================================================================== règles (comme server/src/games/scrabroc.js)

const scrVal = {
  'A': 1, 'B': 3, 'C': 3, 'D': 2, 'E': 1, 'F': 4, 'G': 2, 'H': 4, 'I': 1, 'J': 8, 'K': 10, 'L': 1, 'M': 2, 'N': 1, 'O': 1, 'P': 3,
  'Q': 8, 'R': 1, 'S': 1, 'T': 1, 'U': 1, 'V': 4, 'W': 10, 'X': 10, 'Y': 10, 'Z': 10, '?': 0,
};

/// Cases bonus : un huitième du plateau recopié par symétrie
final Map<String, String> scrBonus = () {
  final m = <String, String>{};
  void sym(String k, List<List<int>> cells) {
    for (final [r, c] in cells) {
      for (final [a, b] in [[r, c], [c, r], [14 - r, c], [r, 14 - c], [14 - r, 14 - c], [c, 14 - r], [14 - c, r], [14 - c, 14 - r]]) {
        m['$a,$b'] = k;
      }
    }
  }

  sym('l2', [[0, 3], [2, 6], [3, 7], [6, 6]]);
  sym('l3', [[1, 5], [5, 5]]);
  sym('w2', [[1, 1], [2, 2], [3, 3], [4, 4]]);
  sym('w3', [[0, 0], [0, 7]]);
  m['7,7'] = 'star';
  return m;
}();

// =================================================================== couleurs (plateau marine, bonus menthe / vert / jaune / corail, cadre bois laqué)

const _boardBg = Color(0xFF1B2647);
const _cell = Color(0xFF26355F);
const _l2 = Color(0xFF7FD9B8);
const _l3 = Color(0xFF1FA387);
const _w2 = Color(0xFFF6C453);
const _w3 = Color(0xFFF07B5A);
const _tile = Color(0xFFFBEFD5);
const _tile2 = Color(0xFFEED9AE);
const _tileInk = Color(0xFF3A2A1C);
const _gold = Color(0xFFE2B45A);
const _pink = Color(0xFFFF4FA3);

const _bonusColor = {'l2': _l2, 'l3': _l3, 'w2': _w2, 'w3': _w3, 'star': _w2};
const _bonusLabel = {'l2': 'L×2', 'l3': 'L×3', 'w2': 'M×2', 'w3': 'M×3', 'star': '★'};

/// Un jeton : lettre + valeur (joker : lettre en orange, sans valeur)
class ScrTile extends StatelessWidget {
  const ScrTile({super.key, required this.letter, required this.size, this.joker = false, this.ring, this.pending = false});
  final String letter;
  final double size;
  final bool joker, pending;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pending ? const [Color(0xFFFFF6A8), Color(0xFFF5D84A)] : const [_tile, _tile2],
        ),
        border: ring == null ? null : Border.all(color: ring!, width: math.max(1.5, size * .07)),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: size * .06, offset: Offset(0, size * .04))],
      ),
      child: Stack(children: [
        Center(
          child: Text(letter == '?' ? '' : letter,
              style: Pb.t(size * .6, weight: 700, color: joker ? const Color(0xFFB4501F) : _tileInk).copyWith(height: 1)),
        ),
        if (!joker && letter != '?')
          Positioned(
            right: size * .08,
            bottom: size * .04,
            child: Text('${scrVal[letter] ?? 0}', style: Pb.t(size * .24, weight: 600, color: _tileInk).copyWith(height: 1)),
          ),
      ]),
    );
  }
}

/// Le plateau 15 × 15 dans son cadre (bois laqué, filet doré, rivets ; coordonnées sur la TV)
class ScrBoard extends StatelessWidget {
  const ScrBoard({
    super.key,
    required this.board,
    required this.size,
    this.pending = const {},
    this.last = const {},
    this.onTap,
    this.coords = false,
    this.badPending = false,
  });
  final List<List<String>> board; // '' = vide, 'A' = lettre, 'a' = joker A
  final double size;
  final Map<String, (String, bool)> pending; // 'r,c' -> (lettre, joker)
  final Set<String> last;
  final void Function(int r, int c)? onTap;
  final bool coords, badPending;

  @override
  Widget build(BuildContext context) {
    final pad = coords ? size * .045 : size * .03;
    final inner = size - pad * 2;
    final gap = inner * .003;
    final cell = (inner - gap * 14 - inner * .012) / 15;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .035),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A4826), Color(0xFF4E2B15), Color(0xFF663B1E), Color(0xFF43250F)],
          stops: [0, .45, .75, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF2A1507), spreadRadius: 3),
          BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 18)),
        ],
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        // filet doré
        Positioned(
          left: -pad * .45,
          top: -pad * .45,
          right: -pad * .45,
          bottom: -pad * .45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * .024),
              border: Border.all(color: _gold, width: math.max(1.2, size * .003)),
              boxShadow: [BoxShadow(color: _gold.withValues(alpha: .25), blurRadius: 8)],
            ),
          ),
        ),
        // rivets
        for (final (x, y) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)])
          Positioned(
            left: x < 0 ? -pad * .82 : null,
            right: x > 0 ? -pad * .82 : null,
            top: y < 0 ? -pad * .82 : null,
            bottom: y > 0 ? -pad * .82 : null,
            child: Container(
              width: pad * .45,
              height: pad * .45,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFFFF0B8), _gold, Color(0xFF7A5414)], stops: [0, .45, 1]),
              ),
            ),
          ),
        if (coords) ...[
          for (var i = 0; i < 15; i++)
            Positioned(
              left: inner * .006 + i * (cell + gap),
              top: -pad * .95,
              width: cell,
              child: Text('ABCDEFGHIJKLMNO'[i], textAlign: TextAlign.center, style: Pb.t(pad * .42, weight: 600, color: const Color(0xFFE9C77E))),
            ),
          for (var i = 0; i < 15; i++)
            Positioned(
              top: inner * .006 + i * (cell + gap) + cell * .25,
              left: -pad * .98,
              width: pad * .9,
              child: Text('${i + 1}', textAlign: TextAlign.center, style: Pb.t(pad * .42, weight: 600, color: const Color(0xFFE9C77E))),
            ),
        ],
        // les cases
        Container(
          padding: EdgeInsets.all(inner * .006),
          decoration: BoxDecoration(color: _boardBg, borderRadius: BorderRadius.circular(size * .015)),
          child: Column(children: [
            for (var r = 0; r < 15; r++)
              Padding(
                padding: EdgeInsets.only(bottom: r < 14 ? gap : 0),
                child: Row(children: [
                  for (var c = 0; c < 15; c++)
                    Padding(
                      padding: EdgeInsets.only(right: c < 14 ? gap : 0),
                      child: GestureDetector(
                        onTap: onTap == null ? null : () => onTap!(r, c),
                        child: _square(r, c, cell),
                      ),
                    ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _square(int r, int c, double s) {
    final k = '$r,$c';
    final t = board[r][c];
    if (t.isNotEmpty) {
      final j = t.toLowerCase() == t;
      return ScrTile(letter: t.toUpperCase(), size: s, joker: j, ring: last.contains(k) ? _pink : null);
    }
    final p = pending[k];
    if (p != null) return ScrTile(letter: p.$1, size: s, joker: p.$2, pending: true, ring: badPending ? Colors.redAccent : null);
    final b = scrBonus[k];
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: b == null ? _cell : _bonusColor[b], borderRadius: BorderRadius.circular(s * .14)),
      alignment: Alignment.center,
      child: b == null
          ? null
          : Text(_bonusLabel[b]!,
              style: Pb.t(b == 'star' ? s * .6 : s * .3, weight: 700, color: b == 'l3' || b == 'w3' ? Colors.white70 : Colors.black54)),
    );
  }
}

List<List<String>> scrBoardOf(Map<String, dynamic> live) => [
      for (final row in (live['board'] as List? ?? const []))
        [for (final x in (row as List)) x as String],
    ];

Set<String> _lastCells(Map<String, dynamic> live) {
  final l = live['last'];
  if (l is! Map || l['kind'] != 'play') return const {};
  return {for (final c in (l['cells'] as List? ?? const [])) '${(c as List)[0]},${c[1]}'};
}

String scrLastText(RoomView room, Map<String, dynamic> live) {
  final l = live['last'];
  if (l is! Map) return 'Le premier mot passe par l’étoile du centre.';
  final who = room.player(l['pid'] as String? ?? '')?.name ?? '?';
  switch (l['kind']) {
    case 'swap':
      return '$who échange ${l['n']} lettre${(l['n'] as num? ?? 0) > 1 ? 's' : ''}';
    case 'pass':
      return '${l['auto'] == true ? '⏰ ' : ''}$who passe son tour';
  }
  final words = [for (final w in (l['words'] as List? ?? const [])) (w as Map)['w'] as String];
  final more = words.length > 1 ? ' (+${words.length - 1} mot${words.length > 2 ? 's' : ''})' : '';
  return '$who : ${words.isEmpty ? '' : words.first}$more · +${l['total']}${l['bingo'] == true ? ' · 7 lettres ! +50' : ''}';
}

// =================================================================== TV

class ScrTv extends StatelessWidget {
  const ScrTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🔤',
        title: 'Scrabroc',
        sub: 'Le plus de points avec ses lettres !',
        rules: const [
          'Pose des mots sur le plateau avec les 7 lettres de ton chevalet. Le premier passe par l’étoile.',
          'Chaque mot touche un mot déjà posé. Les cases L×2 / L×3 comptent la lettre, M×2 / M×3 tout le mot.',
          'Tes 7 lettres d’un coup : +50 ! Les ★ jokers valent 0.',
          'Les mots sont vérifiés tout de suite : un mot inconnu est refusé, tu réessaies.',
        ],
        live: live,
      );
    }
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map];
    final current = live.s('current');
    final hist = [for (final h in (live['hist'] as List? ?? const [])) h as Map];
    final many = players.length > 4;
    return PartyBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RepaintBoundary(child: ScrBoard(board: scrBoardOf(live), size: 1000, last: _lastCells(live), coords: true)),
          const SizedBox(width: 50),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('Scrabroc', style: Pb.t(56, weight: 700)),
                const SizedBox(width: 16),
                Expanded(child: Text('Sac : ${live.i('bag')} lettres', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(26, color: Pb.muted))),
              ]),
              if (ph == 'turn') ...[
                const SizedBox(height: 8),
                TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
              ],
              const SizedBox(height: 16),
              for (final p in players)
                if (room.player(p['pid'] as String) case final pv?)
                  Container(
                    margin: EdgeInsets.only(bottom: many ? 6 : 12),
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: many ? 6 : 12),
                    decoration: BoxDecoration(
                      color: Pb.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: p['pid'] == current ? Pb.yellow : Colors.transparent, width: 4),
                    ),
                    child: Row(children: [
                      PbAvatar(size: many ? 44 : 62, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
                      const SizedBox(width: 16),
                      Expanded(child: Text(pv.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(many ? 26 : 32, weight: 600))),
                      for (var i = 0; i < ((p['rack'] as num?) ?? 0).toInt(); i++)
                        Container(
                          width: 14,
                          height: 18,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(color: _tile2, borderRadius: BorderRadius.circular(3)),
                        ),
                      const SizedBox(width: 18),
                      SizedBox(
                        width: 110,
                        child: Text('${p['score']}', textAlign: TextAlign.right, style: Pb.t(many ? 32 : 42, weight: 700, color: Pb.yellow)),
                      ),
                    ]),
                  ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(live.i('seq')),
                  constraints: const BoxConstraints(minHeight: 90),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(color: _tile, borderRadius: BorderRadius.circular(22)),
                  child: Text(scrLastText(room, live), maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(32, weight: 600, color: _tileInk)),
                ),
              ),
              const SizedBox(height: 16),
              Text('DERNIERS COUPS', style: Pb.t(18, weight: 600, color: Pb.muted).copyWith(letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRect(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final h in hist.skip(1).take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: room.player(h['pid'] as String? ?? '')?.name ?? '?', style: Pb.t(24, weight: 600)),
                                TextSpan(
                                  text: ' · ${h['kind'] == 'play' ? (h['words'] as List? ?? const []).join(', ') : h['kind'] == 'swap' ? 'échange' : 'passe'}',
                                  style: Pb.t(24, color: Pb.muted),
                                ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (((h['total'] as num?) ?? 0) > 0) Text('+${h['total']}', style: Pb.t(24, weight: 600, color: Pb.muted)),
                        ]),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// =================================================================== téléphone

/// Réponse du serveur à `scr_check` (aperçu du coup en cours) : reçue par play_screen.dart
class ScrPreview {
  static final value = ValueNotifier<Map<String, dynamic>?>(null);
}

class ScrPlay extends StatefulWidget {
  const ScrPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<ScrPlay> createState() => _ScrPlayState();
}

class _ScrPlayState extends State<ScrPlay> {
  // Coup en cours : lettres posées (r, c, place sur le chevalet, lettre choisie pour un joker)
  final _pend = <({int r, int c, int i, String? l})>[];
  int? _sel;
  Set<int>? _swap;
  List<int> _order = [];
  String _rackKey = '';
  int _checkKey = 0;

  Map<String, dynamic> get live => widget.live;
  List<String> get _rack => [for (final l in (widget.you?['rack'] as List? ?? const [])) l as String];

  void _g(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': m});

  void _syncRack() {
    final key = '${live.i('seq')}|${_rack.join()}|${widget.you.yb('myTurn')}';
    if (key == _rackKey) return;
    _rackKey = key;
    _order = [for (var i = 0; i < _rack.length; i++) i];
    _pend.clear();
    _sel = null;
    _swap = null;
    ScrPreview.value.value = null;
  }

  void _check() {
    _checkKey++;
    if (_pend.isEmpty) {
      ScrPreview.value.value = null;
      return;
    }
    _g({'t': 'scr_check', 'key': _checkKey, 'tiles': _tiles()});
  }

  List<Map<String, dynamic>> _tiles() => [
        for (final p in _pend) {'r': p.r, 'c': p.c, 'i': p.i, if (p.l != null) 'l': p.l},
      ];

  Future<void> _tapCell(int r, int c) async {
    if (!widget.you.yb('myTurn') || _swap != null) return;
    final k = _pend.indexWhere((p) => p.r == r && p.c == c);
    if (k >= 0) {
      setState(() => _pend.removeAt(k));
      _check();
      return;
    }
    final sel = _sel;
    if (sel == null || _board()[r][c].isNotEmpty) return;
    String? l;
    if (_rack[sel] == '?') {
      l = await _pickLetter();
      if (l == null || !mounted) return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _pend.add((r: r, c: c, i: sel, l: l));
      _sel = null;
    });
    _check();
  }

  Future<String?> _pickLetter() => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Pb.bg2,
          title: Text('Le joker devient…', style: Pb.t(20, weight: 700)),
          content: SizedBox(
            width: 300,
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final l in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
                GestureDetector(onTap: () => Navigator.pop(ctx, l), child: ScrTile(letter: l, size: 42)),
            ]),
          ),
        ),
      );

  List<List<String>> _board() => scrBoardOf(live);

  @override
  Widget build(BuildContext context) {
    _syncRack();
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🔤', title: 'Scrabroc', sub: 'Pose tes mots, vise les cases qui comptent triple !'),
      'podium' => phoneRank(widget.you),
      _ => widget.you?['inGame'] == true ? _game() : const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !'),
    };
    return PhoneGameFrame(stepKey: ph, isHost: widget.isHost, phase: ph, send: widget.send, skipLabel: 'Faire passer', child: body);
  }

  Widget _game() {
    final mine = widget.you.yb('myTurn');
    final room = widget.room;
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final me = (live['players'] as List? ?? const []).cast<Map>().where((p) => p['pid'] == widget.you?['pid']).firstOrNull;
    final rack = _rack;
    final used = {for (final p in _pend) p.i};
    final pending = {for (final p in _pend) '${p.r},${p.c}': (p.l ?? rack[p.i], p.l != null)};

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 40, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              _swap != null ? 'Touche les lettres à échanger' : (mine ? 'À toi ! Pose tes lettres' : '${cur?.name ?? '…'} réfléchit…'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Pb.t(18, weight: 700, color: Pb.yellow),
            ),
          ),
          Text('${me?['score'] ?? 0} pts', style: Pb.t(18, weight: 700)),
        ]),
        if (mine) ...[
          const SizedBox(height: 4),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 4),
        ],
        const SizedBox(height: 6),
        // Le plateau : on pince pour zoomer
        LayoutBuilder(builder: (context, cons) {
          final s = cons.maxWidth;
          return SizedBox(
            width: s,
            height: s,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 3,
                child: ValueListenableBuilder(
                  valueListenable: ScrPreview.value,
                  builder: (context, pv, _) => ScrBoard(
                    board: _board(),
                    size: s,
                    pending: pending,
                    last: _lastCells(live),
                    onTap: _tapCell,
                    badPending: pv != null && pv['key'] == _checkKey && pv['ok'] != true,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Text('Pince le plateau pour zoomer', textAlign: TextAlign.center, style: Pb.t(11, color: Pb.muted)),
        // Aperçu : mots, points ou erreur (calculés par le serveur)
        SizedBox(
          height: 26,
          child: ValueListenableBuilder(
            valueListenable: ScrPreview.value,
            builder: (context, pv, _) {
              if (_pend.isEmpty || pv == null || pv['key'] != _checkKey) return const SizedBox.shrink();
              final ok = pv['ok'] == true;
              final words = [for (final w in (pv['words'] as List? ?? const [])) (w as Map)['w']];
              return Center(
                child: Text(
                  ok ? '${words.join(' + ')} · ${pv['total']} pts${pv['bingo'] == true ? ' (7 lettres !)' : ''}' : '${pv['err'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Pb.t(16, weight: 600, color: ok ? Pb.green : Colors.redAccent),
                ),
              );
            },
          ),
        ),
        const Spacer(),
        // Le chevalet
        Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF6B4426),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black38, offset: Offset(0, 3))],
          ),
          child: LayoutBuilder(builder: (context, cons) {
            final s = math.min(46.0, (cons.maxWidth - 6 * 6) / 7);
            return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final i in _order)
                if (i < rack.length)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: used.contains(i) ? 0 : 1,
                      child: GestureDetector(
                        onTap: !mine || used.contains(i)
                            ? null
                            : () => setState(() {
                                  if (_swap != null) {
                                    _swap!.contains(i) ? _swap!.remove(i) : _swap!.add(i);
                                  } else {
                                    _sel = _sel == i ? null : i;
                                  }
                                }),
                        child: AnimatedSlide(
                          offset: Offset(0, _sel == i ? -.12 : 0),
                          duration: const Duration(milliseconds: 120),
                          child: ScrTile(
                            letter: rack[i],
                            size: s,
                            joker: rack[i] == '?',
                            ring: _sel == i ? Pb.yellow : (_swap?.contains(i) == true ? Pb.cyan : null),
                          ),
                        ),
                      ),
                    ),
                  ),
            ]);
          }),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _act(_swap != null ? '✖ Annuler' : '↩ Reprendre', mine && (_pend.isNotEmpty || _swap != null), () {
            setState(() {
              _pend.clear();
              _swap = null;
              _sel = null;
            });
            _check();
          }),
          _act('🔀 Mélanger', mine, () {
            setState(() {
              _order.shuffle();
              _sel = null;
            });
          }),
          _act('♻ Échanger', mine && _swap == null && widget.you?['canSwap'] == true, () {
            setState(() {
              _pend.clear();
              _sel = null;
              _swap = {};
            });
            _check();
          }),
          _act('⏭ Passer', mine, () => _g({'t': 'scr_pass'})),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: ValueListenableBuilder(
            valueListenable: ScrPreview.value,
            builder: (context, pv, _) {
              final swapping = _swap != null;
              final can = mine && (swapping ? _swap!.isNotEmpty : (_pend.isNotEmpty && pv != null && pv['key'] == _checkKey && pv['ok'] == true));
              return FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Pb.green,
                  foregroundColor: const Color(0xFF17102B),
                  disabledBackgroundColor: Pb.cardHi,
                  disabledForegroundColor: Pb.muted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: !can
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        if (swapping) {
                          _g({'t': 'scr_swap', 'idx': _swap!.toList()});
                        } else {
                          _g({'t': 'scr_play', 'tiles': _tiles()});
                        }
                      },
                child: Text(
                  swapping ? '♻ Échanger ${_swap!.length} lettre${_swap!.length > 1 ? 's' : ''}' : '✔ Valider',
                  style: Pb.t(20, weight: 700, color: can ? const Color(0xFF17102B) : Pb.muted),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _act(String label, bool on, VoidCallback onTap) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Pb.card,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: on ? onTap : null,
            child: FittedBox(child: Text(label, style: Pb.t(13, weight: 600, color: on ? Pb.text : Pb.muted))),
          ),
        ),
      );
}
