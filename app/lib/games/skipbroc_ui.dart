import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

// =================================================================== cartes

/// Couleur de chaque chiffre : une rampe du jaune soleil (1) au bleu nuit (12)
const _ramp = [
  Color(0xFFF6B81E), Color(0xFFF59A1E), Color(0xFFF27B22), Color(0xFFEE5A2C), Color(0xFFE8413F), Color(0xFFE03159),
  Color(0xFFD12C78), Color(0xFFB42F94), Color(0xFF9136AA), Color(0xFF6E3DB8), Color(0xFF4F48C2), Color(0xFF3656C4),
];
const _paper = Color(0xFFFFF8EC);

const sbrBg = BoxDecoration(
  gradient: RadialGradient(center: Alignment(0, -.1), radius: 1.1, colors: [Color(0xFF1C4250), Color(0xFF14303A), Color(0xFF0D2129)], stops: [0, .55, 1]),
);

/// Une carte : [v] 1 à 12, 0 = ★ ; [as] = valeur jouée par un ★ sur une pile ;
/// [card] null = emplacement vide (avec [empty] écrit dedans)
class SbrCard extends StatelessWidget {
  const SbrCard({super.key, required this.card, this.width = 80, this.empty, this.ring, this.lifted = false});
  final Map? card;
  final double width;
  final String? empty;
  final Color? ring;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.45;
    final c = card;
    Widget inner;
    if (c == null) {
      inner = Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(width * .12), border: Border.all(color: Colors.white38, width: width * .035)),
        alignment: Alignment.center,
        child: Text(empty ?? '', style: Pb.t(width * .3, weight: 700, color: Colors.white38)),
      );
    } else {
      final v = (c['v'] as num).toInt();
      final as = (c['as'] as num?)?.toInt();
      inner = DecoratedBox(
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(width * .12),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: width * .12, offset: Offset(0, width * .05))],
        ),
        child: Padding(
          padding: EdgeInsets.all(width * .07),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(width * .09),
              color: v == 0 ? null : _ramp[v - 1],
              gradient: v == 0
                  ? const SweepGradient(colors: [
                      Color(0xFFFF4FA3), Color(0xFFFFB02E), Color(0xFFFFE14D), Color(0xFF4CE38A), Color(0xFF3FE0FF), Color(0xFF8E6BFF), Color(0xFFFF4FA3),
                    ])
                  : null,
            ),
            child: Stack(children: [
              Center(
                child: Text(v == 0 ? '★' : '$v',
                    style: Pb.t(width * (v >= 10 ? .46 : .55), weight: 700, color: Colors.white)
                        .copyWith(shadows: [Shadow(color: const Color(0x55000000), offset: Offset(0, width * .025))])),
              ),
              if (v != 0) ...[
                Positioned(left: width * .03, top: width * .03, child: _corner(v)),
                Positioned(right: width * .03, bottom: width * .03, child: RotatedBox(quarterTurns: 2, child: _corner(v))),
              ],
              if (v == 0 && as != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: width * .06,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: width * .08, vertical: width * .01),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                      child: Text('= $as', style: Pb.t(width * .17, weight: 700, color: Colors.white)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
    }
    return AnimatedSlide(
      offset: Offset(0, lifted ? -.08 : 0),
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: width,
        height: h,
        decoration: ring == null
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(width * .14),
                boxShadow: [BoxShadow(color: ring!, blurRadius: 0, spreadRadius: width * .05)],
              ),
        child: inner,
      ),
    );
  }

  Widget _corner(int v) => Container(
        width: width * .2,
        height: width * .2,
        decoration: const BoxDecoration(color: _paper, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text('$v', style: Pb.t(width * .12, weight: 700, color: _ramp[v - 1])),
      );
}

bool sbrFits(Map? card, int n) => card != null && ((card['v'] as num).toInt() == 0 || (card['v'] as num).toInt() == n + 1);

String sbrEventText(RoomView room, Map<String, dynamic> live) {
  final e = live['event'];
  if (e is! Map) return 'Le premier qui vide son talon gagne.';
  final who = room.player(e['pid'] as String? ?? '')?.name ?? '?';
  final c = e['card'] as Map?;
  final v = (c?['v'] as num?)?.toInt() ?? 0;
  final shown = v == 0 ? '★ (= ${e['as'] ?? '?'})' : '$v';
  if (e['kind'] == 'discard') {
    return '${e['auto'] == true ? '⏰ ' : ''}$who défausse ${v == 0 ? '★' : '$v'} et passe la main';
  }
  if (e['win'] == true) return '🏆 $who a vidé son talon !';
  var t = '$who pose $shown${e['src'] == 'stock' ? ' de son talon' : e['src'] == 'disc' ? ' de sa défausse' : ''}';
  if (e['full'] == true) t += ' · pile complète !';
  if (e['refill'] == true) t += ' · 5 nouvelles cartes';
  return t;
}

List<Map> _builds(Map<String, dynamic> live) => [for (final b in (live['builds'] as List? ?? const [])) b as Map];

// =================================================================== TV

class SbrTv extends StatelessWidget {
  const SbrTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🪜',
        title: 'Skip-Broc',
        sub: 'Vide ton talon le premier ! (${live.i('size', 20)} cartes chacun)',
        rules: const [
          'Au milieu, 4 piles communes qu’on monte de 1 à 12. Le ★ remplace n’importe quel chiffre.',
          'À ton tour, pose ce que tu peux : ta main, le dessus de ton talon ou de tes défausses.',
          'Tu as posé tes 5 cartes de main ? Tu en repioches 5.',
          'Pour finir ton tour, pose une carte de ta main sur une de tes 4 défausses.',
        ],
        live: live,
      );
    }
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map];
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final left = <Map>[], right = <Map>[];
    for (final (i, p) in players.indexed) {
      (i.isEven ? left : right).add(p);
    }

    return DecoratedBox(
      decoration: sbrBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 30, 40, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 80,
            child: Row(children: [
              Text('Skip-Broc', style: Pb.t(52, weight: 700)),
              const SizedBox(width: 22),
              Expanded(child: Text('Vide ton talon le premier !', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(26, color: Pb.muted))),
              if (cur != null)
                Container(
                  constraints: const BoxConstraints(maxWidth: 760),
                  padding: const EdgeInsets.fromLTRB(8, 8, 26, 8),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    PbAvatar(size: 58, emoji: cur.emoji, color: cur.color, photoPath: cur.photo),
                    const SizedBox(width: 14),
                    Text('Au tour de ', style: Pb.t(30)),
                    Flexible(child: Text(cur.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(32, weight: 700, color: Pb.yellow))),
                  ]),
                ),
            ]),
          ),
          if (ph == 'turn') ...[
            const SizedBox(height: 8),
            TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
          ],
          const SizedBox(height: 18),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _column(left, current, Alignment.centerLeft)),
              const SizedBox(width: 24),
              SizedBox(width: 820, child: _center()),
              const SizedBox(width: 24),
              Expanded(child: _column(right, current, Alignment.centerRight)),
            ]),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(live.i('seq')),
              height: 78,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 26),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(22)),
              child: Text(sbrEventText(room, live), maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(32, weight: 600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _center() {
    final builds = _builds(live);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final b in builds)
          Column(mainAxisSize: MainAxisSize.min, children: [
            SbrCard(card: b['top'] as Map?, width: 168, empty: '1'),
            const SizedBox(height: 12),
            SizedBox(
              width: 190,
              child: FittedBox(fit: BoxFit.scaleDown, child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'il faut un ', style: Pb.t(24, color: Pb.muted)),
                TextSpan(text: '${((b['n'] as num?) ?? 0).toInt() + 1}', style: Pb.t(30, weight: 700)),
              ]),
            ))),
          ]),
      ]),
      const SizedBox(height: 34),
      Text('Pioche : ${live.i('draw')} cartes · ★ remplace n’importe quel chiffre', style: Pb.t(24, color: Pb.muted)),
    ]);
  }

  Widget _column(List<Map> ps, String? current, Alignment align) {
    if (ps.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final p in ps)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: align, child: _panel(p, p['pid'] == current)),
          ),
        ),
      // Peu de joueurs : les panneaux ne grossissent pas au-delà de leur taille
      for (var k = ps.length; k < 3; k++) const Expanded(child: SizedBox.shrink()),
    ]);
  }

  Widget _panel(Map p, bool now) {
    final pv = room.player(p['pid'] as String);
    final discs = [for (final d in (p['discs'] as List? ?? const [])) d as Map];
    return Container(
      width: 440,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: now ? Pb.yellow : Colors.transparent, width: 4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (pv != null) PbAvatar(size: 46, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
          const SizedBox(width: 12),
          Expanded(child: Text(pv?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(28, weight: 600))),
          Text('${p['hand']} en main', style: Pb.t(19, color: Pb.muted)),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(children: [
            SbrCard(card: p['stockTop'] as Map?, width: 92),
            const SizedBox(height: 4),
            SizedBox(
              width: 110,
              child: FittedBox(fit: BoxFit.scaleDown, child: Text.rich(TextSpan(children: [
                TextSpan(text: '${p['stock']}', style: Pb.t(26, weight: 700, color: Pb.yellow)),
                TextSpan(text: ' au talon', style: Pb.t(16, color: Pb.muted)),
              ]))),
            ),
          ]),
          const SizedBox(width: 14),
          for (final d in discs)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 26),
              child: SbrCard(card: d['top'] as Map?, width: 62),
            ),
        ]),
      ]),
    );
  }
}

// =================================================================== téléphone

class SbrPlay extends StatefulWidget {
  const SbrPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<SbrPlay> createState() => _SbrPlayState();
}

class _SbrPlayState extends State<SbrPlay> {
  // Carte choisie : 'hand' / 'stock' / 'disc' et son numéro
  String? _src;
  int _i = 0;
  int _seq = -1;

  Map<String, dynamic> get live => widget.live;

  void _g(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': m});

  @override
  void didUpdateWidget(covariant SbrPlay old) {
    super.didUpdateWidget(old);
    final seq = live.i('seq');
    if (seq != _seq) {
      _seq = seq;
      _src = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🪜', title: 'Skip-Broc', sub: 'Monte les piles de 1 à 12 et vide ton talon le premier !'),
      'podium' => phoneRank(widget.you),
      _ => widget.you?['inGame'] == true ? _game() : const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !'),
    };
    return DecoratedBox(
      decoration: sbrBg,
      child: PhoneGameFrame(stepKey: ph, isHost: widget.isHost, phase: ph, send: widget.send, skipLabel: 'Faire passer', child: body),
    );
  }

  Widget _tap(Widget child, VoidCallback? onTap) => GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child);

  Widget _game() {
    final room = widget.room;
    final myPid = widget.you?['pid'] as String?;
    final mine = widget.you.yb('myTurn');
    final me = (live['players'] as List? ?? const []).cast<Map>().where((p) => p['pid'] == myPid).firstOrNull;
    if (me == null) return const SizedBox.shrink();
    final hand = [for (final c in (widget.you?['hand'] as List? ?? const [])) c as Map];
    final discs = [for (final d in (me['discs'] as List? ?? const [])) d as Map];
    final builds = _builds(live);
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    if (_src == 'hand' && _i >= hand.length) _src = null;
    final Map? sel = switch (_src) {
      'hand' => hand[_i],
      'stock' => me['stockTop'] as Map?,
      'disc' => discs[_i]['top'] as Map?,
      _ => null,
    };

    void choose(String src, int i) {
      if (!mine) return;
      HapticFeedback.selectionClick();
      setState(() {
        if (_src == src && _i == i) {
          _src = null;
        } else {
          _src = src;
          _i = i;
        }
      });
    }

    final state = !mine ? (cur == null ? '' : '${cur.name} joue…') : 'À toi de jouer !';
    final hint = !mine
        ? 'Regarde la TV'
        : sel == null
            ? 'Touche une carte à jouer'
            : _src == 'hand'
                ? 'Touche une pile verte, ou une défausse rose pour finir ton tour'
                : 'Touche une pile verte';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(state, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(22, weight: 700, color: Pb.yellow)),
        if (mine) ...[
          const SizedBox(height: 6),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 5),
        ],
        const SizedBox(height: 12),
        _label('Piles communes'),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final (b, pile) in builds.indexed)
            () {
              final n = ((pile['n'] as num?) ?? 0).toInt();
              final ok = mine && sel != null && sbrFits(sel, n);
              return _tap(
                SbrCard(card: pile['top'] as Map?, width: 70, empty: '1', ring: ok ? Pb.green : null),
                ok
                    ? () {
                        HapticFeedback.mediumImpact();
                        _g({'t': 'sbr_play', 'src': _src, 'i': _i, 'b': b});
                        setState(() => _src = null);
                      }
                    : null,
              );
            }(),
        ]),
        const SizedBox(height: 14),
        _label('Mon talon et mes défausses'),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(18)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Column(children: [
              _tap(
                SbrCard(card: me['stockTop'] as Map?, width: 76, ring: _src == 'stock' ? Pb.yellow : null, lifted: _src == 'stock'),
                me['stockTop'] == null ? null : () => choose('stock', 0),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 84,
                child: FittedBox(fit: BoxFit.scaleDown, child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${me['stock']}', style: Pb.t(18, weight: 700, color: Pb.yellow)),
                  TextSpan(text: ' au talon', style: Pb.t(12, color: Pb.muted)),
                ]))),
              ),
            ]),
            const Spacer(),
            for (final (d, disc) in discs.indexed)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 22),
                child: _tap(
                  SbrCard(
                    card: disc['top'] as Map?,
                    width: 50,
                    ring: mine && _src == 'hand' ? Pb.pink : (_src == 'disc' && _i == d ? Pb.yellow : null),
                    lifted: _src == 'disc' && _i == d,
                  ),
                  !mine
                      ? null
                      : () {
                          if (_src == 'hand') {
                            HapticFeedback.mediumImpact();
                            _g({'t': 'sbr_discard', 'i': _i, 'd': d});
                            setState(() => _src = null);
                          } else if (disc['top'] != null) {
                            choose('disc', d);
                          }
                        },
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(hint, textAlign: TextAlign.center, style: Pb.t(14, color: Pb.muted)),
        const Spacer(),
        _label('Ma main'),
        LayoutBuilder(builder: (context, cons) {
          final w = math.min(64.0, (cons.maxWidth - 4 * 6) / 5);
          return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final (i, c) in hand.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _tap(
                  SbrCard(card: c, width: w, ring: _src == 'hand' && _i == i ? Pb.yellow : null, lifted: _src == 'hand' && _i == i),
                  () => choose('hand', i),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t.toUpperCase(), style: Pb.t(12, weight: 600, color: Pb.muted).copyWith(letterSpacing: 1)),
      );
}
