import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'pouilleux_ui.dart' show PouCard, pouBg;

// Le tas de merde : on passe une carte à son voisin, carré = on tape sur le tas, le dernier à taper
// pioche des kilos de merde. Mêmes cartes que le Pouilleux (`PouCard`).

String _ms(int ms) => '+${(ms / 1000).toStringAsFixed(2).replaceAll('.', ',')} s';

const _rankName = {'A': 'as', 'V': 'valet', 'D': 'dame', 'R': 'roi'};
String _carreName(String r) => 'carré ${_rankName[r] == null ? 'de $r' : (r == 'A' ? 'd’as' : 'de ${_rankName[r]}s')}';

/// Le tas au milieu : une pile de dos un peu en désordre
class TasPile extends StatelessWidget {
  const TasPile({super.key, required this.count, this.width = 120});
  final int count;
  final double width;

  @override
  Widget build(BuildContext context) {
    final n = math.min(6, math.max(1, (count / 6).ceil()));
    const tilt = [-.10, .07, -.03, .12, -.08, .02];
    return SizedBox(
      width: width * 1.5,
      height: width * 1.45 * 1.2,
      child: Stack(alignment: Alignment.center, children: [
        for (var k = 0; k < n; k++)
          Transform.translate(
            offset: Offset((k % 3 - 1) * width * .06, -k * width * .03),
            child: Transform.rotate(angle: tilt[k], child: PouCard(card: null, width: width)),
          ),
      ]),
    );
  }
}

String _kilos(int k) => '$k kilo${k > 1 ? 's' : ''}';

// =================================================================== TV

class TasTv extends StatelessWidget {
  const TasTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '💩',
        title: 'Le tas de merde',
        sub: 'Fais un carré et tape sur le tas ! (${live.i('manches')} manches)',
        rules: const [
          'Chacun a 4 cartes. Tous ensemble, on passe une carte à son voisin, encore et encore.',
          'Tu as 4 cartes pareilles ? TAPE sur le tas avec ton téléphone !',
          'Quelqu’un a tapé ? Tape vite toi aussi : le dernier pioche des kilos de merde.',
          'Le 7, c’est la chasse d’eau : tous tes kilos partent ! Taper sans carré : 2 kilos.',
        ],
        live: live,
      );
    }
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map];
    final n = players.length;
    final taps = [for (final t in (live['taps'] as List? ?? const [])) t as Map];
    final tapIdx = {for (final (i, t) in taps.indexed) t['pid'] as String: i};
    final losers = {for (final d in (live['draws'] as List? ?? const [])) (d as Map)['pid'] as String};
    final scale = n > 10 ? .8 : (n > 7 ? .9 : 1.0);
    const cx = 960.0, cy = 590.0, rx = 790.0, ry = 380.0;

    return DecoratedBox(
      decoration: pouBg,
      child: Stack(children: [
        Positioned(
          left: cx - 590, top: cy - 285, width: 1180, height: 570,
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(590, 285)),
              gradient: RadialGradient(center: Alignment(0, -.2), radius: .9, colors: [Color(0xFF7A5634), Color(0xFF5E3F22), Color(0xFF462D16)]),
              boxShadow: [
                BoxShadow(color: Color(0xFF3B200C), spreadRadius: 18),
                BoxShadow(color: Color(0xFF241205), spreadRadius: 24),
                BoxShadow(color: Colors.black54, spreadRadius: 24, blurRadius: 50, offset: Offset(0, 30)),
              ],
            ),
          ),
        ),
        Positioned(left: cx - 480, top: cy - 230, width: 960, height: 460, child: _center(ph)),
        Positioned(
          left: 40, top: 26,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('💩 Le tas de merde', style: Pb.t(44, weight: 700)),
            Text('Manche ${live.i('manche')} / ${live.i('manches')}', style: Pb.t(24, color: Pb.muted)),
          ]),
        ),
        if (ph == 'pick' || ph == 'tap')
          Positioned(left: 600, right: 600, top: 40, child: TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8)),
        for (final (k, p) in players.indexed)
          () {
            final a = math.pi / 2 + 2 * math.pi * k / n;
            final x = cx + rx * math.cos(a), y = cy + ry * math.sin(a);
            final pid = p['pid'] as String;
            return Positioned(
              left: x - 170, top: y - 85, width: 340, height: 170,
              child: Center(
                child: Transform.scale(scale: scale, child: _seat(p, tapIdx[pid], losers.contains(pid), ph)),
              ),
            );
          }(),
      ]),
    );
  }

  Widget _center(String ph) {
    final first = live.s('first');
    final fv = first == null ? null : room.player(first);
    final carre = [for (final c in (live['carre'] as List? ?? const [])) c as Map];
    final draws = [for (final d in (live['draws'] as List? ?? const [])) d as Map];
    final ev = live['event'] as Map?;

    if (ph == 'tap') {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🖐 ${fv?.name ?? '?'} a tapé !', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(64, weight: 700, color: Pb.yellow)),
        if (carre.isNotEmpty) Text('Avec un ${_carreName(carre.first['r'] as String)}', style: Pb.t(28, color: Colors.white70)),
        const SizedBox(height: 6),
        Text('TAPEZ TOUS SUR LE TAS !', style: Pb.t(40, weight: 700, color: Pb.pink)),
        const SizedBox(height: 18),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final c in carre) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: PouCard(card: c, width: 110)),
        ]),
      ]);
    }
    if (ph == 'penalty') {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final d in draws.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.rotate(angle: -.06, child: PouCard(card: d['card'] as Map, width: draws.length > 1 ? 140 : 180)),
              const SizedBox(height: 14),
              () {
                final pv = room.player(d['pid'] as String);
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  if (pv != null) PbAvatar(size: 48, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: draws.length > 1 ? 220 : 520),
                    child: Text(pv?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(32, weight: 700)),
                  ),
                ]);
              }(),
              const SizedBox(height: 4),
              Text(
                d['flush'] == true ? '🚽 Chasse d’eau ! 0 kilo' : '💩 +${(d['after'] as num) - (d['before'] as num)} kilos',
                style: Pb.t(draws.length > 1 ? 26 : 34, weight: 700, color: d['flush'] == true ? Pb.cyan : Pb.pink),
              ),
              Text(d['late'] == true ? 'n’a pas tapé à temps' : 'dernier à taper', style: Pb.t(20, color: Colors.white70)),
            ]),
          ),
        if (draws.length > 3) Text('+${draws.length - 3}', style: Pb.t(40, weight: 700)),
      ]);
    }
    final String text;
    if (ev != null && ev['kind'] == 'false' && ph != 'deal') {
      text = '😬 ${room.player(ev['pid'] as String? ?? '')?.name ?? '?'} a tapé sans carré : +2 kilos !';
    } else if (ph == 'deal') {
      text = 'Manche ${live.i('manche')} : 4 cartes chacun !';
    } else if (ph == 'swap') {
      text = 'Les cartes passent au voisin…';
    } else {
      text = 'Choisissez une carte à passer à votre voisin';
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TasPile(count: live.i('pile'), width: 120),
      Text('Le tas · ${live.i('pile')} cartes', style: Pb.t(22, color: Colors.white70)),
      const SizedBox(height: 16),
      Container(
        constraints: const BoxConstraints(maxWidth: 900),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(18)),
        child: Text(text, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(30, weight: 600)),
      ),
    ]);
  }

  Widget _seat(Map p, int? tapped, bool loser, String ph) {
    final pv = room.player(p['pid'] as String);
    final kilos = (p['kilos'] as num?)?.toInt() ?? 0;
    final picked = p['picked'] == true;
    final border = loser ? Pb.pink : (tapped != null ? Pb.green : (picked ? Pb.cyan : Colors.transparent));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(5, 5, 16, 5),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99), border: Border.all(color: border, width: 4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (pv != null) PbAvatar(size: 46, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
          const SizedBox(width: 10),
          Flexible(child: Text(pv?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(24, weight: 600))),
          const SizedBox(width: 10),
          Text('💩 $kilos', style: Pb.t(24, weight: 700, color: kilos > 0 ? Pb.yellow : Pb.muted)),
        ]),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 64,
        child: tapped != null
            ? Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: (loser ? Pb.pink : Pb.green).withValues(alpha: .25), borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    tapped == 0 ? '🖐 Carré !' : '🖐 ${tapped + 1}e · ${_ms(((((live['taps'] as List)[tapped] as Map)['ms']) as num).toInt())}',
                    style: Pb.t(22, weight: 700, color: loser ? Pb.pink : Pb.green),
                  ),
                ),
              )
            : Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var k = 0; k < 4; k++)
                    Align(widthFactor: .62, child: PouCard(card: null, width: 44, lift: picked && k == 3 && ph == 'pick')),
                ]),
                if (picked && ph == 'pick') Positioned(right: -30, top: 4, child: Text('✓', style: Pb.t(30, weight: 700, color: Pb.cyan))),
              ]),
      ),
    ]);
  }
}

// =================================================================== téléphone

class TasPlay extends StatefulWidget {
  const TasPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<TasPlay> createState() => _TasPlayState();
}

class _TasPlayState extends State<TasPlay> {
  Map<String, dynamic> get live => widget.live;
  void _g(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': m});

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '💩', title: 'Le tas de merde', sub: 'Fais un carré, tape sur le tas… et ne sois pas le dernier à taper !'),
      'podium' => phoneRank(widget.you),
      _ => widget.you?['inGame'] == true ? _game() : const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !'),
    };
    return DecoratedBox(
      decoration: pouBg,
      child: PhoneGameFrame(stepKey: ph, isHost: widget.isHost, phase: ph, send: widget.send, skipLabel: 'Faire passer', child: body),
    );
  }

  Widget _game() {
    final room = widget.room;
    final ph = live.phase;
    final you = widget.you;
    final myPid = you?['pid'] as String?;
    final hand = [for (final c in (you?['hand'] as List? ?? const [])) c as Map];
    final picked = (you?['picked'] as num?)?.toInt();
    final got = (you?['got'] as num?)?.toInt();
    final tapped = you.yb('tapped');
    final kilos = you.yi('kilos') ?? 0;
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map];
    final me = players.indexWhere((p) => p['pid'] == myPid);
    final next = me < 0 || players.isEmpty ? null : room.player(players[(me + 1) % players.length]['pid'] as String);
    final first = live.s('first');
    final draws = [for (final d in (live['draws'] as List? ?? const [])) d as Map];
    final myDraw = draws.where((d) => d['pid'] == myPid).firstOrNull;
    final taps = [for (final t in (live['taps'] as List? ?? const [])) t as Map];
    final myTap = taps.indexWhere((t) => t['pid'] == myPid);

    final String state;
    Color stateColor = Pb.yellow;
    if (ph == 'tap' && !tapped) {
      state = '🖐 ${room.player(first ?? '')?.name ?? '?'} a tapé ! TAPE !';
      stateColor = Pb.pink;
    } else if (ph == 'tap' || (ph == 'penalty' && myTap >= 0 && myDraw == null)) {
      state = myTap == 0 ? 'Carré ! Bien joué 🖐' : 'Tapé ! ${myTap + 1}e (${_ms(((taps[myTap]['ms']) as num).toInt())})';
      stateColor = Pb.green;
    } else if (ph == 'penalty' && myDraw != null) {
      state = myDraw['flush'] == true ? '🚽 Chasse d’eau ! Tes kilos partent' : '💩 Tu pioches ${(myDraw['after'] as num) - (myDraw['before'] as num)} kilos !';
      stateColor = myDraw['flush'] == true ? Pb.cyan : Pb.pink;
    } else if (ph == 'penalty') {
      state = draws.isEmpty ? '' : '${draws.map((d) => room.player(d['pid'] as String)?.name ?? '?').join(', ')} pioche${draws.length > 1 ? 'nt' : ''} !';
    } else if (ph == 'deal') {
      state = 'Manche ${live.i('manche')} / ${live.i('manches')}';
    } else if (ph == 'swap') {
      state = 'Les cartes passent…';
      stateColor = Pb.muted;
    } else {
      state = picked == null ? 'Passe une carte à ${next?.name ?? 'ton voisin'}' : 'Carte choisie : touche-la encore pour changer';
    }

    final canTap = (ph == 'pick' || ph == 'swap' || ph == 'deal') || (ph == 'tap' && !tapped);
    final urgent = ph == 'tap' && !tapped;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Manche ${live.i('manche')}/${live.i('manches')}', style: Pb.t(14, color: Pb.muted)),
          const SizedBox(width: 14),
          Text('💩 ${_kilos(kilos)}', style: Pb.t(16, weight: 700, color: kilos > 0 ? Pb.yellow : Pb.muted)),
        ]),
        const SizedBox(height: 6),
        Text(state, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(20, weight: 700, color: stateColor)),
        if (ph == 'pick' || ph == 'tap') ...[
          const SizedBox(height: 6),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 5),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: ph == 'penalty' && myDraw != null
                ? PouCard(card: myDraw['card'] as Map, width: 120)
                : LayoutBuilder(builder: (context, cons) {
                    final w = math.min(96.0, (cons.maxWidth - 4 * 10) / 4);
                    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final c in hand)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: ph != 'pick'
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    _g({'t': 'tas_pick', 'id': c['id']});
                                  },
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              PouCard(
                                card: c,
                                width: w,
                                ring: picked == c['id'] ? Pb.yellow : (got == c['id'] && ph != 'deal' ? Pb.cyan : null),
                                lift: picked == c['id'],
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 18,
                                child: Text(
                                  picked == c['id'] ? 'à passer' : (got == c['id'] ? 'reçue' : ''),
                                  style: Pb.t(13, weight: 600, color: picked == c['id'] ? Pb.yellow : Pb.cyan),
                                ),
                              ),
                            ]),
                          ),
                        ),
                    ]);
                  }),
          ),
        ),
        _TapButton(enabled: canTap, urgent: urgent, onTap: () {
          HapticFeedback.heavyImpact();
          _g({'t': 'tas_tap'});
        }),
        const SizedBox(height: 6),
        Text('4 cartes pareilles ? Tape ! (sans carré : +2 kilos)', textAlign: TextAlign.center, style: Pb.t(12, color: Pb.muted)),
      ]),
    );
  }
}

/// Le gros bouton « TAPE ! », qui bat quand quelqu'un a tapé
class _TapButton extends StatefulWidget {
  const _TapButton({required this.enabled, required this.urgent, required this.onTap});
  final bool enabled, urgent;
  final VoidCallback onTap;

  @override
  State<_TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<_TapButton> with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void initState() {
    super.initState();
    if (widget.urgent) _beat.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TapButton old) {
    super.didUpdateWidget(old);
    if (widget.urgent && !_beat.isAnimating) {
      _beat.repeat(reverse: true);
    } else if (!widget.urgent && _beat.isAnimating) {
      _beat
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _beat,
      builder: (context, child) => Transform.scale(scale: 1 + _beat.value * .06, child: child),
      child: GestureDetector(
        // Au toucher (pas au lâcher) : chaque milliseconde compte
        onTapDown: widget.enabled ? (_) => widget.onTap() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.urgent ? 150 : 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: !widget.enabled ? Pb.card : (widget.urgent ? Pb.pink : const Color(0xFF8A5A2B)),
            borderRadius: BorderRadius.circular(28),
            boxShadow: widget.enabled ? [BoxShadow(color: (widget.urgent ? Pb.pink : Colors.black).withValues(alpha: .5), blurRadius: 18, offset: const Offset(0, 6))] : null,
          ),
          child: Text('🖐 TAPE !', style: Pb.t(widget.urgent ? 52 : 40, weight: 700, color: widget.enabled ? Colors.white : Pb.muted)),
        ),
      ),
    );
  }
}
