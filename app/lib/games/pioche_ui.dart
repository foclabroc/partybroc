import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

// =================================================================== cartes

const _colorNames = {'r': 'rouge', 'j': 'jaune', 'v': 'vert', 'b': 'bleu'};

Color pchColor(String c) => switch (c) {
      'r' => const Color(0xFFE8443A),
      'j' => const Color(0xFFF5C318),
      'v' => const Color(0xFF2FB25C),
      'b' => const Color(0xFF2D7FE0),
      _ => const Color(0xFF241B3D),
    };

// « passe » et « sens » sont dessinés avec des icônes (la police n'a pas ces symboles)
String _symbol(String v) => switch (v) {
      'skip' => '',
      'rev' => '',
      'p2' => '+2',
      'p4' => '+4',
      'joker' => '',
      _ => v,
    };

String _cardName(Map card) => switch (card['v']) {
      'skip' => 'Passe ${_colorNames[card['c']] ?? ''}',
      'rev' => 'Sens ${_colorNames[card['c']] ?? ''}',
      'p2' => '+2 ${_colorNames[card['c']] ?? ''}',
      'p4' => '+4',
      'joker' => 'Couleur',
      _ => '${card['v']} ${_colorNames[card['c']] ?? ''}',
    };

/// Une carte de Broc-Pioche (largeur [w], hauteur 1,5 × w)
class PchCard extends StatelessWidget {
  const PchCard({super.key, required this.c, required this.v, required this.w, this.dim = false, this.glow = false});
  final String c, v;
  final double w;
  final bool dim, glow;

  factory PchCard.of(Map card, double w, {bool dim = false, bool glow = false}) =>
      PchCard(c: card['c'] as String, v: card['v'] as String, w: w, dim: dim, glow: glow);

  @override
  Widget build(BuildContext context) {
    final wild = c == 'w';
    final sym = _symbol(v);
    final icon = switch (v) { 'skip' => Icons.block_rounded, 'rev' => Icons.swap_horiz_rounded, _ => null };
    final light = c == 'j';
    final fg = light ? const Color(0xFF3A2A00) : Colors.white;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: dim ? .38 : 1,
      child: Container(
        width: w,
        height: w * 1.5,
        decoration: BoxDecoration(
          color: pchColor(c),
          borderRadius: BorderRadius.circular(w * .14),
          border: Border.all(color: Colors.white, width: w * .05),
          boxShadow: [
            if (glow) BoxShadow(color: Pb.yellow.withValues(alpha: .8), blurRadius: w * .25, spreadRadius: w * .03),
            BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: w * .08, offset: Offset(0, w * .04)),
          ],
        ),
        child: Stack(children: [
          // Carte noire : un losange des 4 couleurs au centre
          if (wild)
            Center(
              child: Transform.rotate(
                angle: .785,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(w * .08),
                  child: SizedBox(
                    width: w * .5,
                    height: w * .5,
                    child: Column(children: [
                      Expanded(child: Row(children: [Expanded(child: ColoredBox(color: pchColor('r'))), Expanded(child: ColoredBox(color: pchColor('b')))])),
                      Expanded(child: Row(children: [Expanded(child: ColoredBox(color: pchColor('j'))), Expanded(child: ColoredBox(color: pchColor('v')))])),
                    ]),
                  ),
                ),
              ),
            ),
          if (sym.isNotEmpty)
            Center(
              child: Text(sym,
                  style: Pb.t(w * (sym.length > 1 ? .46 : .62), weight: 700, color: fg).copyWith(
                    shadows: [Shadow(color: Colors.black.withValues(alpha: light ? 0 : .35), offset: Offset(0, w * .02), blurRadius: w * .03)],
                  )),
            ),
          if (icon != null) Center(child: Icon(icon, size: w * .62, color: fg)),
          // Petits symboles dans les coins (pas retournés : un 6 resterait un 6)
          if ((sym.isNotEmpty || icon != null) && w >= 60) ...[
            Positioned(left: w * .09, top: w * .05, child: _corner(sym, icon, fg)),
            Positioned(right: w * .09, bottom: w * .05, child: _corner(sym, icon, fg)),
          ],
        ]),
      ),
    );
  }
}

extension on PchCard {
  Widget _corner(String sym, IconData? icon, Color fg) =>
      icon != null ? Icon(icon, size: w * .2, color: fg) : Text(sym, style: Pb.t(w * .17, weight: 700, color: fg));
}

/// Dos de carte (la pioche)
class PchBack extends StatelessWidget {
  const PchBack({super.key, required this.w});
  final double w;

  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: w * 1.5,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Pb.pink, Color(0xFF7B3FE4)]),
          borderRadius: BorderRadius.circular(w * .14),
          border: Border.all(color: Colors.white, width: w * .05),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: w * .08, offset: Offset(0, w * .04))],
        ),
        child: Transform.rotate(angle: -.35, child: Text('PB', style: Pb.t(w * .38, weight: 700))),
      );
}

/// Texte de la dernière action (« Ana pose +2 », « Ben pioche 4 cartes »…)
String? pchEventText(RoomView room, Map<String, dynamic> live) {
  final e = live['event'];
  if (e is! Map) return null;
  String name(Object? pid) => pid is String ? (room.player(pid)?.name ?? '?') : '?';
  final who = name(e['pid']);
  final n = (e['n'] as num?)?.toInt() ?? 0;
  return switch (e['k']) {
    'play' => '$who pose ${e['card'] is Map ? _cardName(e['card'] as Map) : 'une carte'}'
        '${(e['card'] as Map?)?['c'] == 'w' ? ' : ${_colorNames[e['color']] ?? ''}' : ''}',
    'draw' => e['forced'] == true
        ? '$who pioche $n carte${n > 1 ? 's' : ''} 😱'
        : (e['late'] == true ? '⏰ $who n’a pas joué : il pioche' : '$who pioche'),
    'pass' => e['late'] == true ? '⏰ $who n’a pas joué' : '$who garde sa carte et passe',
    'skip' => '🚫 $who passe son tour',
    'last' => '📢 $who : « Dernière carte ! »',
    'catch' => '🚨 ${name(e['by'])} dénonce $who : +$n !',
    'out' => '🏆 $who n’a plus de cartes : ${e['place'] == 1 ? '1re' : '${e['place']}e'} place !',
    _ => null,
  };
}

// =================================================================== TV

class PchTv extends StatelessWidget {
  const PchTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    return switch (ph) {
      'intro' => TvIntro(
          emoji: '🃏',
          title: 'Broc-Pioche',
          sub: 'Vide ta main le premier !',
          rules: const [
            'Pose une carte de la même couleur ou du même symbole. Sinon, pioche.',
            'Les +2 et +4 se cumulent : renvoie-les au suivant !',
            'Plus qu’une carte ? Touche « Dernière carte ! », sinon les autres peuvent te dénoncer (+2).',
          ],
          live: live),
      'play' => _table(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _table() {
    final top = live['top'] as Map?;
    final color = live.s('color') ?? 'w';
    final pending = live.i('pending');
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final ev = pchEventText(room, live);
    final order = [for (final o in (live['order'] as List? ?? const [])) o as Map];
    final finished = live.pids('finished');
    final exposed = live.s('exposed');
    final avatar = order.length > 10 ? 74.0 : 92.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(70, 36, 70, 30),
      child: Column(children: [
        Row(children: [
          Text('🃏 Broc-Pioche', style: Pb.t(46, weight: 700)),
          const Spacer(),
          TvChip(text: live.i('dir') == 1 ? '🔃 sens horaire' : '🔄 sens inverse', color: Pb.cyan, size: 32),
          const SizedBox(width: 20),
          TvChip(text: '🃏 ${live.i('deck')} dans la pioche', color: Pb.muted, size: 32),
        ]),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const PchBack(w: 200),
            const SizedBox(width: 70),
            // La carte du dessus, avec la couleur à jouer autour
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 1.3, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
              child: Container(
                key: ValueKey(top?['id']),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: pchColor(color).withValues(alpha: .35), borderRadius: BorderRadius.circular(54)),
                child: top == null ? const SizedBox(width: 260, height: 390) : PchCard.of(top, 260),
              ),
            ),
            const SizedBox(width: 60),
            SizedBox(
              width: 520,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Couleur : ${_colorNames[color] ?? '?'}', style: Pb.t(44, weight: 700, color: pchColor(color) == pchColor('w') ? Pb.text : pchColor(color))),
                if (pending > 0) ...[
                  const SizedBox(height: 18),
                  TvChip(text: '+$pending à piocher !', bg: Pb.red, size: 50),
                ],
                const SizedBox(height: 26),
                if (cur != null)
                  Row(children: [
                    PbAvatar(size: 90, emoji: cur.emoji, color: cur.color, photoPath: cur.photo),
                    const SizedBox(width: 18),
                    Expanded(child: Text('À ${cur.name} de jouer', maxLines: 2, style: Pb.t(46, weight: 700, color: Pb.yellow))),
                  ]),
              ]),
            ),
          ]),
        ),
        // Dernière action
        SizedBox(
          height: 70,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(ev ?? '', key: ValueKey(live.i('seq')), textAlign: TextAlign.center, style: Pb.t(44, weight: 600)),
          ),
        ),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 12),
        const SizedBox(height: 22),
        // Les joueurs dans l'ordre de passage, avec leur nombre de cartes
        Wrap(alignment: WrapAlignment.center, spacing: 22, runSpacing: 14, children: [
          for (final o in order)
            if (room.player(o['pid'] as String) case final p?)
              _seat(p, (o['n'] as num).toInt(), o['pid'] == current, o['said'] == true, o['pid'] == exposed, avatar),
          for (final pid in finished)
            if (room.player(pid) case final p?)
              Opacity(
                opacity: .7,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  PbAvatar(size: avatar * .8, emoji: p.emoji, color: p.color, photoPath: p.photo),
                  Text('${switch (finished.indexOf(pid)) { 0 => '🥇', 1 => '🥈', 2 => '🥉', _ => '🏁' }} ${p.name}', style: Pb.t(24, weight: 600)),
                ]),
              ),
        ]),
      ]),
    );
  }

  Widget _seat(PlayerView p, int n, bool now, bool said, bool exposed, double size) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: now ? 1.12 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: BoxDecoration(
          color: now ? Pb.cardHi : Pb.card.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: now ? Pb.yellow : Colors.transparent, width: 4),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            PbAvatar(size: size, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !p.connected),
            if (exposed) const Positioned(right: -10, top: -10, child: Text('⚠️', style: TextStyle(fontSize: 36))),
            if (said && n == 1) const Positioned(right: -10, top: -10, child: Text('📢', style: TextStyle(fontSize: 36))),
          ]),
          const SizedBox(height: 4),
          SizedBox(width: size + 30, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Pb.t(24, weight: 600))),
          Text('🃏 $n', style: Pb.t(30, weight: 700, color: n == 1 ? Pb.red : Pb.yellow)),
        ]),
      ),
    );
  }
}

// =================================================================== téléphone

class PchPlay extends StatelessWidget {
  const PchPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final String? myPid;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  void _g(Map<String, dynamic> m) => send({'t': 'game_msg', 'm': m});

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(
          emoji: '🃏',
          title: 'Broc-Pioche',
          sub: 'Même couleur ou même symbole. Vide ta main le premier ! N’oublie pas « Dernière carte ! »'),
      'play' => _play(context),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(
      stepKey: ph == 'play' ? 'play' : ph,
      isHost: isHost,
      phase: ph,
      send: send,
      skipLabel: 'Faire passer',
      child: body,
    );
  }

  Widget _play(BuildContext context) {
    if (you?['inGame'] != true) {
      return const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !');
    }
    final hand = [for (final c in (you?['hand'] as List? ?? const [])) c as Map];
    final place = you.yi('place');
    if (place != null || hand.isEmpty) {
      return PhoneCenter(
        emoji: place == 1 ? '🏆' : '🏁',
        title: place == null ? 'Plus de cartes !' : 'Tu finis ${place == 1 ? '1er' : '${place}e'} !',
        sub: 'Regarde les autres finir sur la TV…',
        color: place == 1 ? Pb.yellow : Pb.green,
      );
    }
    final playable = {for (final x in (you?['playable'] as List? ?? const [])) (x as num).toInt()};
    final myTurn = you.yb('myTurn');
    final drawn = you.yi('drawn');
    final pending = live.i('pending');
    final top = live['top'] as Map?;
    final color = live.s('color') ?? 'w';
    final current = live.s('current');
    final exposed = live.s('exposed');
    final saidMe = [for (final o in (live['order'] as List? ?? const [])) o as Map].any((o) => o['pid'] == myPid && o['said'] == true);
    final ev = pchEventText(room, live);
    final w = hand.length > 14 ? 54.0 : (hand.length > 8 ? 62.0 : 74.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // La carte du dessus et à qui c'est
        Row(children: [
          if (top != null)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: pchColor(color).withValues(alpha: .45), borderRadius: BorderRadius.circular(14)),
              child: PchCard.of(top, 50),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                myTurn ? 'À toi de jouer !' : 'À ${room.player(current ?? '')?.name ?? '…'} de jouer',
                style: Pb.t(myTurn ? 26 : 20, weight: 700, color: myTurn ? Pb.yellow : Pb.text),
              ),
              Text('Couleur : ${_colorNames[color] ?? '?'}${pending > 0 ? ' · +$pending à piocher' : ''}',
                  style: Pb.t(15, weight: 600, color: pending > 0 ? Pb.red : Pb.muted)),
              if (ev != null) Text(ev, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(14, color: Pb.muted)),
            ]),
          ),
        ]),
        if (myTurn) ...[const SizedBox(height: 8), TimeBar(endsIn: live.endsIn, duration: live.duration, height: 6)],
        // Quelqu'un a oublié d'annoncer sa dernière carte : on peut le dénoncer
        if (exposed != null && exposed != myPid) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Pb.red),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _g({'t': 'pch_catch', 'pid': exposed});
            },
            icon: const Text('🚨'),
            label: Text('${room.player(exposed)?.name ?? '?'} a oublié ! Dénonce (+2)'),
          ),
        ],
        const SizedBox(height: 10),
        // Ma main
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(spacing: 8, runSpacing: 10, alignment: WrapAlignment.center, children: [
              for (final c in hand)
                GestureDetector(
                  onTap: myTurn && playable.contains((c['id'] as num).toInt()) ? () => _playCard(context, c, hand.length) : null,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 150),
                    offset: Offset(0, myTurn && playable.contains((c['id'] as num).toInt()) ? -.08 : 0),
                    child: PchCard.of(c, w,
                        dim: myTurn && !playable.contains((c['id'] as num).toInt()),
                        glow: drawn != null && drawn == (c['id'] as num).toInt()),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        if (hand.length <= 2 && !saidMe)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Pb.yellow, foregroundColor: Pb.bg),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _g({'t': 'pch_last'});
              },
              child: const Text('📢 Dernière carte !'),
            ),
          ),
        if (myTurn)
          drawn != null
              ? OutlinedButton(onPressed: () => _g({'t': 'pch_pass'}), child: const Text('Garder la carte et passer'))
              : FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _g({'t': 'pch_draw'});
                  },
                  icon: const Text('🃏'),
                  label: Text(pending > 0 ? 'Piocher $pending cartes' : (playable.isEmpty ? 'Piocher' : 'Piocher quand même')),
                ),
      ]),
    );
  }

  Future<void> _playCard(BuildContext context, Map card, int handSize) async {
    HapticFeedback.selectionClick();
    String? color;
    if (card['c'] == 'w') {
      color = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Pb.bg2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Quelle couleur ?', textAlign: TextAlign.center, style: Pb.t(22, weight: 700)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final c in const ['r', 'j', 'v', 'b'])
                    Material(
                      color: pchColor(c),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pop(ctx, c),
                        child: Center(child: Text(_colorNames[c]!.toUpperCase(), style: Pb.t(22, weight: 700, color: c == 'j' ? Pb.bg : Colors.white))),
                      ),
                    ),
                ],
              ),
            ]),
          ),
        ),
      );
      if (color == null) return;
    }
    _g({'t': 'pch_play', 'card': card['id'], 'color': ?color});
  }
}
