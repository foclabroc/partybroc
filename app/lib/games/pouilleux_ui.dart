import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

// Le Pouilleux : jeu de cartes classique redessiné (enseignes dessinées par nous, pas de police).
// Les mains ne sont jamais dans l'état public : la TV et le voisin qui pioche ne voient que des dos,
// dans l'ordre de la main mais en miroir (comme assis en face).

const _paper = Color(0xFFFFFDF6);
const _red = Color(0xFFD22F3C);
const _black = Color(0xFF1E1B2E);
const _gold = Color(0xFFD9A62E);

const pouBg = BoxDecoration(
  gradient: RadialGradient(center: Alignment(0, 0), radius: 1.0, colors: [Color(0xFF2A2060), Color(0xFF1A1240)]),
);

bool _isRed(String s) => s == 'c' || s == 'k';

const _rankWord = {
  'A': 'd’as', 'R': 'de rois', 'D': 'de dames', 'V': 'de valets',
  '10': 'de 10', '9': 'de 9', '8': 'de 8', '7': 'de 7', '6': 'de 6', '5': 'de 5', '4': 'de 4', '3': 'de 3', '2': 'de 2',
};

String pouCardName(Map c) {
  final r = c['r'] as String? ?? '';
  final s = c['s'] as String? ?? '';
  final rank = switch (r) { 'A' => 'l’as', 'R' => 'le roi', 'D' => 'la dame', 'V' => 'le valet', _ => 'le $r' };
  final suit = switch (s) { 'c' => 'cœur', 'k' => 'carreau', 'p' => 'pique', _ => 'trèfle' };
  return '$rank de $suit';
}

/// Éventail qui tient dans [width] : les cartes se chevauchent plus quand il y en a beaucoup ;
/// si le pas descend sous [minStep], on passe sur 2 rangées.
({double step, int perRow}) pouFan(int n, double cardW, double width, double maxStep, double minStep) {
  final perRow = n <= 1 ? 1 : ((width - cardW) / (n - 1) >= minStep ? n : (n / 2).ceil());
  final step = perRow <= 1 ? 0.0 : math.min(maxStep, (width - cardW) / (perRow - 1));
  return (step: step, perRow: perRow);
}

// =================================================================== enseignes

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit);
  final String suit;

  static Path path(String s, Size z) {
    final w = z.width, h = z.height;
    Offset p(double x, double y) => Offset(x * w, y * h);
    final path = Path();
    switch (s) {
      case 'c': // cœur
        path.moveTo(p(.5, .95).dx, p(.5, .95).dy);
        path.cubicTo(p(.05, .62).dx, p(.05, .62).dy, p(-.04, .26).dx, p(-.04, .26).dy, p(.24, .1).dx, p(.24, .1).dy);
        path.cubicTo(p(.38, .03).dx, p(.38, .03).dy, p(.5, .14).dx, p(.5, .14).dy, p(.5, .26).dx, p(.5, .26).dy);
        path.cubicTo(p(.5, .14).dx, p(.5, .14).dy, p(.62, .03).dx, p(.62, .03).dy, p(.76, .1).dx, p(.76, .1).dy);
        path.cubicTo(p(1.04, .26).dx, p(1.04, .26).dy, p(.95, .62).dx, p(.95, .62).dy, p(.5, .95).dx, p(.5, .95).dy);
        path.close();
      case 'k': // carreau
        path.moveTo(p(.5, .02).dx, p(.5, .02).dy);
        path.lineTo(p(.86, .5).dx, p(.86, .5).dy);
        path.lineTo(p(.5, .98).dx, p(.5, .98).dy);
        path.lineTo(p(.14, .5).dx, p(.14, .5).dy);
        path.close();
      case 'p': // pique
        path.moveTo(p(.5, .03).dx, p(.5, .03).dy);
        path.cubicTo(p(.96, .38).dx, p(.96, .38).dy, p(1.04, .66).dx, p(1.04, .66).dy, p(.74, .73).dx, p(.74, .73).dy);
        path.cubicTo(p(.6, .76).dx, p(.6, .76).dy, p(.53, .68).dx, p(.53, .68).dy, p(.5, .62).dx, p(.5, .62).dy);
        path.cubicTo(p(.47, .68).dx, p(.47, .68).dy, p(.4, .76).dx, p(.4, .76).dy, p(.26, .73).dx, p(.26, .73).dy);
        path.cubicTo(p(-.04, .66).dx, p(-.04, .66).dy, p(.04, .38).dx, p(.04, .38).dy, p(.5, .03).dx, p(.5, .03).dy);
        path.close();
        path.moveTo(p(.5, .58).dx, p(.5, .58).dy);
        path.lineTo(p(.64, .98).dx, p(.64, .98).dy);
        path.lineTo(p(.36, .98).dx, p(.36, .98).dy);
        path.close();
      default: // trèfle
        final r = math.min(w, h) * .21;
        path.addOval(Rect.fromCircle(center: p(.5, .27), radius: r));
        path.addOval(Rect.fromCircle(center: p(.27, .56), radius: r));
        path.addOval(Rect.fromCircle(center: p(.73, .56), radius: r));
        path.addRect(Rect.fromPoints(p(.4, .3), p(.6, .6)));
        path.moveTo(p(.5, .5).dx, p(.5, .5).dy);
        path.lineTo(p(.64, .98).dx, p(.64, .98).dy);
        path.lineTo(p(.36, .98).dx, p(.36, .98).dy);
        path.close();
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path(suit, size), Paint()..color = _isRed(suit) ? _red : _black);
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit;
}

class _Suit extends StatelessWidget {
  const _Suit(this.suit, this.size);
  final String suit;
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _SuitPainter(suit));
}

/// Couronne des figures : 5 pointes pour le roi, 3 pour la dame, une toque à plume pour le valet
class _CrownPainter extends CustomPainter {
  _CrownPainter(this.rank);
  final String rank;

  @override
  void paint(Canvas canvas, Size z) {
    final w = z.width, h = z.height;
    final fill = Paint()..color = _gold;
    if (rank == 'V') {
      final cap = Path()
        ..moveTo(w * .12, h * .9)
        ..quadraticBezierTo(w * .14, h * .3, w * .5, h * .3)
        ..quadraticBezierTo(w * .86, h * .3, w * .88, h * .9)
        ..close();
      canvas.drawPath(cap, fill);
      final plume = Path()
        ..moveTo(w * .55, h * .34)
        ..quadraticBezierTo(w * .8, h * .0, w * .98, h * .08)
        ..quadraticBezierTo(w * .8, h * .22, w * .62, h * .4)
        ..close();
      canvas.drawPath(plume, fill);
      return;
    }
    final points = rank == 'R' ? 5 : 3;
    final path = Path()..moveTo(w * .08, h * .95);
    path.lineTo(w * .08, h * .3);
    for (var k = 0; k < points; k++) {
      final x0 = .08 + .84 * k / points, x1 = .08 + .84 * (k + .5) / points, x2 = .08 + .84 * (k + 1) / points;
      if (k > 0) path.lineTo(w * x0, h * .3);
      path.lineTo(w * ((x0 + x1) / 2), h * .58);
      path.lineTo(w * x1, h * .08);
      path.lineTo(w * ((x1 + x2) / 2), h * .58);
      path.lineTo(w * x2, h * .3);
    }
    path.lineTo(w * .92, h * .95);
    path.close();
    canvas.drawPath(path, fill);
    for (var k = 0; k < points; k++) {
      final x = .08 + .84 * (k + .5) / points;
      canvas.drawCircle(Offset(w * x, h * .08), w * .05, fill);
    }
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.rank != rank;
}

/// Dos : rayures violettes, cadre et losange dorés
class _BackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size z) {
    final w = z.width, h = z.height;
    final inner = RRect.fromRectAndRadius(Rect.fromLTWH(w * .07, w * .07, w * .86, h - w * .14), Radius.circular(w * .06));
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawRect(Offset.zero & z, Paint()..color = const Color(0xFF4A25A0));
    final stripe = Paint()
      ..color = const Color(0xFF5B2FB8)
      ..strokeWidth = math.max(2, w * .07);
    final gap = math.max(4.0, w * .14);
    for (double x = -h; x < w + h; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), stripe);
    }
    canvas.restore();
    canvas.drawRRect(inner, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * .025)
      ..color = const Color(0x99FFD23F));
    final d = w * .17;
    final c = Offset(w / 2, h / 2);
    final diamond = Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d, c.dy)
      ..close();
    canvas.drawPath(diamond, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, w * .05)
      ..color = const Color(0xFF3B1E7A));
    canvas.drawPath(diamond, Paint()..color = const Color(0xFFFFD23F));
  }

  @override
  bool shouldRepaint(_BackPainter old) => false;
}

// Places des enseignes d'une carte à points (0..1 dans la zone du milieu)
const _pips = <int, List<(double, double)>>{
  2: [(.5, 0), (.5, 1)],
  3: [(.5, 0), (.5, .5), (.5, 1)],
  4: [(0, 0), (1, 0), (0, 1), (1, 1)],
  5: [(0, 0), (1, 0), (.5, .5), (0, 1), (1, 1)],
  6: [(0, 0), (1, 0), (0, .5), (1, .5), (0, 1), (1, 1)],
  7: [(0, 0), (1, 0), (.5, .25), (0, .5), (1, .5), (0, 1), (1, 1)],
  8: [(0, 0), (1, 0), (.5, .25), (0, .5), (1, .5), (.5, .75), (0, 1), (1, 1)],
  9: [(0, 0), (1, 0), (0, 1 / 3), (1, 1 / 3), (.5, .5), (0, 2 / 3), (1, 2 / 3), (0, 1), (1, 1)],
  10: [(0, 0), (1, 0), (.5, 1 / 6), (0, 1 / 3), (1, 1 / 3), (0, 2 / 3), (1, 2 / 3), (.5, 5 / 6), (0, 1), (1, 1)],
};

/// Une carte : [card] `{id, r, s}` ou null = dos. [ring] = contour de couleur, [lift] = soulevée.
class PouCard extends StatelessWidget {
  const PouCard({super.key, required this.card, this.width = 70, this.ring, this.lift = false});
  final Map? card;
  final double width;
  final Color? ring;
  final bool lift;

  @override
  Widget build(BuildContext context) {
    final w = width, h = width * 1.45;
    final c = card;
    final radius = BorderRadius.circular(w * .09);
    Widget face;
    if (c == null) {
      face = CustomPaint(size: Size(w, h), painter: _BackPainter());
    } else {
      final r = c['r'] as String? ?? '';
      final s = c['s'] as String? ?? '';
      final col = _isRed(s) ? _red : _black;
      final fs = w * .2;
      Widget corner() => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(r, style: TextStyle(fontFamily: 'Fredoka', fontSize: fs, height: .95, fontWeight: FontWeight.w700, color: col, letterSpacing: r == '10' ? -fs * .08 : 0)),
            _Suit(s, fs * .72),
          ]);
      Widget mid;
      if (r == 'R' || r == 'D' || r == 'V') {
        mid = Padding(
          padding: EdgeInsets.symmetric(horizontal: w * .17, vertical: h * .17),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(w * .06),
              border: Border.all(color: _gold, width: math.max(1.2, w * .025)),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: _isRed(s) ? const [Color(0xFFFFE4E1), Color(0xFFF6C1BA)] : const [Color(0xFFFFF3D6), Color(0xFFF3DCA4)],
              ),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CustomPaint(size: Size(w * .3, w * .2), painter: _CrownPainter(r)),
              Text(r, style: TextStyle(fontFamily: 'Fredoka', fontSize: w * .34, height: 1, fontWeight: FontWeight.w700, color: col)),
              _Suit(s, w * .18),
            ]),
          ),
        );
      } else if (r == 'A') {
        mid = Center(child: _Suit(s, w * .52));
      } else {
        final n = int.tryParse(r) ?? 0;
        final ps = _pips[n] ?? const [];
        final pw = w * (n >= 9 ? .16 : .18);
        final left = w * .27, top = h * .17, zw = w * .46, zh = h * .66 - pw;
        mid = Stack(children: [
          for (final (x, y) in ps)
            Positioned(
              left: left + x * zw - pw / 2,
              top: top + y * zh,
              child: Transform.rotate(angle: y > .5 ? math.pi : 0, child: _Suit(s, pw)),
            ),
        ]);
      }
      face = Stack(children: [
        Positioned.fill(child: mid),
        Positioned(left: w * .05, top: h * .03, child: corner()),
        Positioned(right: w * .05, bottom: h * .03, child: Transform.rotate(angle: math.pi, child: corner())),
      ]);
    }
    return AnimatedSlide(
      duration: const Duration(milliseconds: 160),
      offset: Offset(0, lift ? -.18 : 0),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: c == null ? const Color(0xFF3B1E7A) : _paper,
          borderRadius: radius,
          boxShadow: [
            if (ring != null) BoxShadow(color: ring!, spreadRadius: math.max(2, w * .045)),
            BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: w * .12, offset: Offset(0, w * .05)),
          ],
        ),
        child: ClipRRect(borderRadius: radius, child: face),
      ),
    );
  }
}

/// Dos d'une main vue d'en face : [n] cartes en miroir. [pick] = place (dans l'ordre de la main)
/// mise en avant, [onTap] reçoit la place réelle.
class PouBacks extends StatelessWidget {
  const PouBacks({super.key, required this.n, required this.cardW, required this.width, this.maxStep = 30, this.minStep = 9, this.pick, this.pickColor = Pb.pink, this.onTap, this.rows = 1});
  final int n;
  final double cardW, width, maxStep, minStep;
  final int? pick;
  final Color pickColor;
  final void Function(int)? onTap;
  final int rows; // 1 = toujours une rangée, 2 = deux rangées permises

  @override
  Widget build(BuildContext context) {
    if (n == 0) return SizedBox(height: cardW * 1.45);
    var fan = pouFan(n, cardW, width, maxStep, minStep);
    if (rows == 1 && fan.perRow < n) {
      fan = (step: n <= 1 ? 0 : (width - cardW) / (n - 1), perRow: n);
    }
    final h = cardW * 1.45;
    final nRows = (n / fan.perRow).ceil();
    final rowW = cardW + fan.step * (math.min(n, fan.perRow) - 1);
    final lift = h * .18;
    return SizedBox(
      width: rowW,
      height: nRows * h + (nRows - 1) * 8 + lift,
      child: Stack(clipBehavior: Clip.none, children: [
        for (var j = 0; j < n; j++)
          () {
            final k = n - 1 - j; // vue d'en face : la dernière carte de la main est à gauche
            final row = j ~/ fan.perRow, col = j % fan.perRow;
            final card = PouCard(card: null, width: cardW, ring: pick == k ? pickColor : null, lift: pick == k);
            return Positioned(
              left: col * fan.step,
              top: lift + row * (h + 8),
              child: onTap == null
                  ? card
                  : GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTap!(k), child: card),
            );
          }(),
      ]),
    );
  }
}

String pouEventText(RoomView room, Map<String, dynamic> live, {String? me}) {
  String who(String? pid) => pid == null ? '?' : (pid == me ? 'toi' : room.player(pid)?.name ?? '?');
  String subj(String? pid) => pid == me ? 'Tu' : who(pid);
  final ph = live.phase;
  final cur = live.s('current');
  final tgt = live.s('target');
  if (ph == 'deal') {
    final d = live.i('dealt');
    return d == 0 ? 'Distribution : aucune paire en main, on commence !' : 'Distribution : $d paire${d > 1 ? 's' : ''} posée${d > 1 ? 's' : ''} d’office au milieu';
  }
  final ev = live['event'] as Map?;
  if (ph == 'turn') {
    final mix = ev != null && ev['kind'] == 'shuffle' && ev['pid'] == tgt ? '🔀 ${subj(tgt)} ${tgt == me ? 'as' : 'a'} mélangé · ' : '';
    if (live['hover'] != null) return '$mix${subj(cur)} ${cur == me ? 'hésites' : 'hésite'} sur une carte de ${who(tgt)}…';
    return '$mix${subj(cur)} ${cur == me ? 'pioches' : 'pioche'} chez ${who(tgt)}';
  }
  if (ph == 'took' && ev != null && ev['kind'] == null) {
    final pid = ev['pid'] as String?, from = ev['from'] as String?;
    final pair = ev['pair'] as List?;
    var t = '${subj(pid)} ${pid == me ? 'as pris' : 'a pris'} une carte à ${who(from)}${ev['auto'] == true ? ' (au hasard)' : ''}';
    if (pair != null && pair.isNotEmpty) t += ' : une paire ${_rankWord[(pair.first as Map)['r']] ?? ''} !';
    final saved = [for (final s in (ev['saved'] as List? ?? const [])) s as String];
    for (final s in saved) {
      t += ' ${s == me ? 'Tu es sauvé' : '${who(s)} est sauvé'} !';
    }
    return t;
  }
  return '';
}

String _place(int n) => n == 1 ? '1er' : '${n}e';

// =================================================================== TV

class PouTv extends StatelessWidget {
  const PouTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🤡',
        title: 'Le Pouilleux',
        sub: 'Ne garde pas le valet de pique ! (${live.i('deck')} cartes)',
        rules: const [
          'Les paires (même valeur, même couleur) partent au milieu.',
          'À ton tour, pioche une carte cachée chez ton voisin : tout le monde voit laquelle tu vises.',
          'Plus de cartes = sauvé ! Le valet de trèfle a été retiré…',
          '… celui qui garde le valet de pique à la fin est le Pouilleux !',
        ],
        live: live,
      );
    }
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map];
    final n = players.length;
    final current = live.s('current');
    final target = live.s('target');
    final hover = (live['hover'] as num?)?.toInt();
    final saved = [for (final p in players) if (p['saved'] != null) p]..sort((a, b) => (a['saved'] as num).compareTo(b['saved'] as num));
    final scale = n > 10 ? .78 : (n > 7 ? .9 : 1.0);
    const cx = 960.0, cy = 590.0, rx = 790.0, ry = 380.0;

    return DecoratedBox(
      decoration: pouBg,
      child: Stack(children: [
        // Table de feutre
        Positioned(
          left: cx - 590, top: cy - 285, width: 1180, height: 570,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.all(Radius.elliptical(590, 285)),
              gradient: RadialGradient(center: Alignment(0, -.2), radius: .9, colors: [Color(0xFF1E7656), Color(0xFF145A41), Color(0xFF0E4532)]),
              boxShadow: [
                BoxShadow(color: Color(0xFF5A3418), spreadRadius: 18),
                BoxShadow(color: Color(0xFF3B200C), spreadRadius: 24),
                BoxShadow(color: Colors.black54, spreadRadius: 24, blurRadius: 50, offset: Offset(0, 30)),
              ],
            ),
          ),
        ),
        Positioned(left: cx - 480, top: cy - 200, width: 960, height: 400, child: _center()),
        // Titre et sauvés
        Positioned(
          left: 40, top: 26,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🤡 Le Pouilleux', style: Pb.t(44, weight: 700)),
            Text('Ne garde pas le valet de pique !', style: Pb.t(22, color: Pb.muted)),
          ]),
        ),
        if (saved.isNotEmpty)
          Positioned(
            right: 40, top: 26,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('✅ Sauvés', style: Pb.t(20, weight: 700, color: Pb.green)),
                for (final p in saved.take(8))
                  Text('${p['saved']}. ${room.player(p['pid'] as String)?.name ?? '?'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(20)),
                if (saved.length > 8) Text('…', style: Pb.t(20, color: Pb.muted)),
              ]),
            ),
          ),
        if (ph == 'turn')
          Positioned(left: 600, right: 600, top: 40, child: TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8)),
        // Places autour de la table, dans le sens des aiguilles d'une montre depuis le bas
        for (final (k, p) in players.indexed)
          () {
            final a = math.pi / 2 + 2 * math.pi * k / n;
            final x = cx + rx * math.cos(a), y = cy + ry * math.sin(a);
            return Positioned(
              left: x - 170, top: y - 95, width: 340, height: 190,
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: _seat(p, now: p['pid'] == current, tgt: p['pid'] == target, hover: p['pid'] == target ? hover : null),
                ),
              ),
            );
          }(),
        if (ph == 'reveal') Positioned.fill(child: _reveal()),
      ]),
    );
  }

  Widget _center() {
    final pairs = [for (final p in (live['pairs'] as List? ?? const [])) p as List];
    final text = pouEventText(room, live);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 520, height: 190,
        child: Stack(clipBehavior: Clip.none, children: [
          for (final (k, pr) in pairs.indexed) ...[
            Positioned(
              left: 60 + k * 62.0, top: 12 + (k - 2.5).abs() * 5,
              child: Transform.rotate(angle: (-14 + k * 6) * math.pi / 180, child: PouCard(card: pr[0] as Map, width: 96)),
            ),
            Positioned(
              left: 82 + k * 62.0, top: 24 + (k - 2.5).abs() * 5,
              child: Transform.rotate(angle: (-9 + k * 6) * math.pi / 180, child: PouCard(card: pr[1] as Map, width: 96)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 8),
      Text('${live.i('pile')} paire${live.i('pile') > 1 ? 's' : ''} au milieu', style: Pb.t(22, color: Colors.white70)),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Container(
          key: ValueKey(text),
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(18)),
          child: Text(text, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(28, weight: 600)),
        ),
      ),
    ]);
  }

  Widget _seat(Map p, {required bool now, required bool tgt, int? hover}) {
    final pv = room.player(p['pid'] as String);
    final count = (p['n'] as num?)?.toInt() ?? 0;
    final saved = (p['saved'] as num?)?.toInt();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(5, 5, 18, 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: now ? Pb.yellow : (tgt ? Pb.pink : Colors.transparent), width: 4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (pv != null) PbAvatar(size: 46, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
          const SizedBox(width: 10),
          Flexible(child: Text(pv?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(24, weight: 600))),
          if (saved == null) ...[
            const SizedBox(width: 8),
            Text('$count', style: Pb.t(22, weight: 700, color: Pb.yellow)),
            Text(count > 1 ? ' cartes' : ' carte', style: Pb.t(18, color: Pb.muted)),
          ],
        ]),
      ),
      const SizedBox(height: 6),
      if (saved != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: Pb.green.withValues(alpha: .25), borderRadius: BorderRadius.circular(14)),
          child: Text('✅ Sauvé · ${_place(saved)}', style: Pb.t(22, weight: 700, color: Pb.green)),
        )
      else
        PouBacks(n: count, cardW: 58, width: 300, maxStep: 32, minStep: 6, pick: hover),
    ]);
  }

  Widget _reveal() {
    final loser = live.s('loser');
    final pv = loser == null ? null : room.player(loser);
    final card = live['loserCard'] as Map?;
    final gage = live.s('gage');
    return Container(
      color: Colors.black.withValues(alpha: .72),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (card != null) Transform.rotate(angle: -.12, child: PouCard(card: card, width: 260)),
        const SizedBox(width: 70),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (pv != null) PbAvatar(size: 170, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Text('${pv?.name ?? '?'} est le Pouilleux !', style: Pb.t(76, weight: 700, color: Pb.yellow)),
          ),
          if (gage != null) ...[
            const SizedBox(height: 18),
            Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
              decoration: BoxDecoration(color: Pb.pink.withValues(alpha: .25), borderRadius: BorderRadius.circular(24), border: Border.all(color: Pb.pink, width: 3)),
              child: Text('Gage : $gage', style: Pb.t(40, weight: 600)),
            ),
          ],
        ]),
      ]),
    );
  }
}

// =================================================================== téléphone

class PouPlay extends StatefulWidget {
  const PouPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<PouPlay> createState() => _PouPlayState();
}

class _PouPlayState extends State<PouPlay> {
  // Ordre affiché de ma main (identifiants) : celui du serveur, sauf pendant que je glisse une carte
  List<int> _order = [];
  int? _drag; // identifiant de la carte tenue
  List<int>? _dragStart;
  final _handKey = GlobalKey();
  // Dernière carte qu'on m'a prise (par différence entre deux mains)
  Map? _lost;
  int _lostSeq = -1;

  Map<String, dynamic> get live => widget.live;
  List<Map> get _hand => [for (final c in (widget.you?['hand'] as List? ?? const [])) c as Map];

  void _g(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': m});

  @override
  void initState() {
    super.initState();
    _order = [for (final c in _hand) c['id'] as int];
  }

  @override
  void didUpdateWidget(covariant PouPlay old) {
    super.didUpdateWidget(old);
    final ids = [for (final c in _hand) c['id'] as int];
    final oldHand = [for (final c in (old.you?['hand'] as List? ?? const [])) c as Map];
    final ev = live['event'] as Map?;
    final me = widget.you?['pid'];
    if (ev != null && ev['from'] == me && (ev['seq'] as num).toInt() != _lostSeq) {
      final gone = oldHand.where((c) => !ids.contains(c['id'])).toList();
      if (gone.length == 1) {
        _lost = gone.first;
        _lostSeq = (ev['seq'] as num).toInt();
      }
    }
    final same = ids.length == _order.length && ids.toSet().containsAll(_order);
    if (_drag != null && same) return; // je range : on garde mon ordre jusqu'au lâcher
    _drag = null;
    _order = ids;
  }

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🤡', title: 'Le Pouilleux', sub: 'Fais tes paires et ne garde pas le valet de pique !'),
      'podium' => phoneRank(widget.you),
      'reveal' => _reveal(),
      _ => widget.you?['inGame'] == true ? _game() : const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !'),
    };
    return DecoratedBox(
      decoration: pouBg,
      child: PhoneGameFrame(stepKey: ph, isHost: widget.isHost, phase: ph, send: widget.send, skipLabel: 'Faire passer', child: body),
    );
  }

  Widget _reveal() {
    final loser = live.s('loser');
    final pv = loser == null ? null : widget.room.player(loser);
    final mine = loser == widget.you?['pid'];
    final gage = live.s('gage');
    return PhoneCenter(
      emoji: mine ? '🤡' : '😅',
      title: mine ? 'Tu es le Pouilleux !' : '${pv?.name ?? '?'} est le Pouilleux !',
      sub: gage == null ? null : 'Gage : $gage',
      color: mine ? Pb.pink : Pb.yellow,
    );
  }

  Widget _game() {
    final room = widget.room;
    final myPid = widget.you?['pid'] as String?;
    final ph = live.phase;
    final mine = widget.you.yb('myTurn');
    final savedRank = widget.you.yi('saved');
    final current = live.s('current');
    final target = live.s('target');
    final hover = (live['hover'] as num?)?.toInt();
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map];
    final tgtN = ((players.where((p) => p['pid'] == target).firstOrNull?['n'] as num?) ?? 0).toInt();
    final onMe = ph == 'turn' && target == myPid && !mine;
    final ev = live['event'] as Map?;
    final cur = current == null ? null : room.player(current);
    final tgt = target == null ? null : room.player(target);

    final String state;
    if (savedRank != null) {
      state = '✅ Sauvé ! (${_place(savedRank)})';
    } else if (ph == 'deal') {
      state = 'Distribution…';
    } else if (mine) {
      state = 'À toi ! Pioche chez ${tgt?.name ?? '?'}';
    } else if (onMe) {
      state = '😱 ${cur?.name ?? '?'} pioche chez toi !';
    } else {
      state = pouEventText(room, live, me: myPid);
    }

    Widget middle;
    if (mine) {
      middle = LayoutBuilder(builder: (context, cons) {
        var nw = 62.0;
        var fan = pouFan(tgtN, nw, cons.maxWidth, 48, 22);
        if (fan.perRow < tgtN) nw = 46;
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _label('Les cartes de ${tgt?.name ?? '?'}'),
          const SizedBox(height: 4),
          PouBacks(
            n: tgtN, cardW: nw, width: cons.maxWidth, maxStep: nw == 62 ? 48 : 40, minStep: 22, rows: 2,
            pick: hover, pickColor: Pb.yellow,
            onTap: (k) {
              HapticFeedback.selectionClick();
              _g({'t': 'pou_hover', 'i': hover == k ? -1 : k});
            },
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Pb.pink, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14)),
            onPressed: hover == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    _g({'t': 'pou_take', 'i': hover});
                  },
            child: Text(hover == null ? 'Touche une carte' : 'Prendre cette carte', style: Pb.t(18, weight: 700)),
          ),
        ]);
      });
    } else {
      Widget? shown;
      String msg;
      if (ph == 'took' && ev != null && ev['pid'] == myPid) {
        final pair = ev['pair'] as List?;
        if (pair != null && pair.isNotEmpty) {
          shown = Row(mainAxisSize: MainAxisSize.min, children: [
            PouCard(card: pair[0] as Map, width: 70),
            const SizedBox(width: 8),
            PouCard(card: pair[1] as Map, width: 70),
          ]);
          msg = 'Paire ! Elle part au milieu 🎉';
        } else {
          final h = _hand;
          if (h.isNotEmpty) shown = PouCard(card: h.last, width: 76);
          msg = h.isNotEmpty && h.last['r'] == 'V' && h.last['s'] == 'p' ? 'Aïe… le valet de pique ! 😈' : 'Pas de paire, elle va dans ta main';
        }
      } else if (ph == 'took' && ev != null && ev['from'] == myPid && _lost != null && _lostSeq == (ev['seq'] as num).toInt()) {
        shown = PouCard(card: _lost, width: 76);
        final taker = room.player(ev['pid'] as String? ?? '')?.name ?? '?';
        msg = _lost!['r'] == 'V' && _lost!['s'] == 'p' ? '$taker t’a pris le Pouilleux ! 😁' : '$taker t’a pris ${pouCardName(_lost!)}';
      } else if (savedRank != null) {
        msg = 'Tu as posé toutes tes cartes 🎉 Regarde qui sera le Pouilleux !';
      } else if (onMe && hover != null) {
        msg = 'Il vise la carte soulevée en rouge : glisse-la ailleurs ou mélange !';
      } else if (onMe) {
        msg = 'Il choisit une de tes cartes…';
      } else if (ph == 'deal') {
        msg = pouEventText(room, live, me: myPid);
      } else {
        msg = 'Attends ton tour';
      }
      middle = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (shown != null) ...[shown, const SizedBox(height: 14)],
        Text(msg, textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: onMe ? Pb.pink : Pb.text)),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(state, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(20, weight: 700, color: onMe ? Pb.pink : Pb.yellow)),
        if (mine) ...[
          const SizedBox(height: 6),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 5),
        ],
        const SizedBox(height: 8),
        Expanded(child: middle),
        if (_hand.isNotEmpty) ...[
          Row(children: [
            Expanded(child: _label('Ma main · ${_hand.length} carte${_hand.length > 1 ? 's' : ''}')),
            TextButton.icon(
              onPressed: _hand.length < 2
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      _g({'t': 'pou_shuffle'});
                    },
              icon: const Text('🔀'),
              label: Text('Mélanger', style: Pb.t(15, weight: 600)),
            ),
          ]),
          _myHand(onMe ? hover : null),
          const SizedBox(height: 4),
          Text('Glisse tes cartes pour les ranger : les autres les voient de dos, en miroir', textAlign: TextAlign.center, style: Pb.t(12, color: Pb.muted)),
        ],
      ]),
    );
  }

  // ------------------------------------------------------------ ma main (glisser pour ranger)

  Widget _myHand(int? threatened) {
    final byId = {for (final c in _hand) c['id'] as int: c};
    final order = [for (final id in _order) if (byId.containsKey(id)) id];
    final n = order.length;
    return LayoutBuilder(builder: (context, cons) {
      final width = cons.maxWidth;
      final w = n > 8 ? 58.0 : 66.0;
      final fan = pouFan(n, w, width, 44, 19);
      final h = w * 1.45;
      final rows = (n / fan.perRow).ceil();
      final rowW = w + fan.step * (math.min(n, fan.perRow) - 1);
      final x0 = (width - rowW) / 2;
      final lift = h * .2;
      Offset slot(int j) => Offset(x0 + (j % fan.perRow) * fan.step, lift + (j ~/ fan.perRow) * (h + 8));

      int indexAt(Offset p) {
        // Carte du dessus sous le doigt (la plus à droite d'abord)
        for (var j = n - 1; j >= 0; j--) {
          final s = slot(j);
          if (Rect.fromLTWH(s.dx, s.dy, w, h).contains(p)) return j;
        }
        return -1;
      }

      int placeFor(Offset p) {
        // Rangée la plus proche, puis nombre d'autres cartes dont le centre est avant le doigt
        final row = ((p.dy - lift - h / 2) / (h + 8)).round().clamp(0, rows - 1);
        final col = ((p.dx - x0 - w / 2) / math.max(1, fan.step)).round().clamp(0, fan.perRow - 1);
        return math.min(n - 1, row * fan.perRow + col);
      }

      final children = <Widget>[];
      Widget? dragged;
      for (var j = 0; j < n; j++) {
        final id = order[j];
        final s = slot(j);
        final isDrag = _drag == id;
        final k = j; // place réelle dans ma main (même ordre que le serveur)
        final w0 = AnimatedPositioned(
          key: ValueKey(id),
          duration: const Duration(milliseconds: 130),
          left: s.dx,
          top: s.dy,
          child: PouCard(
            card: byId[id],
            width: w,
            ring: isDrag ? Pb.yellow : (threatened == k ? _red : null),
            lift: isDrag || threatened == k,
          ),
        );
        if (isDrag || (_drag == null && threatened == k)) {
          dragged = w0;
        } else {
          children.add(w0);
        }
      }
      if (dragged != null) children.add(dragged);

      return SizedBox(
        key: _handKey,
        height: lift + rows * h + (rows - 1) * 8,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            final j = indexAt(d.localPosition);
            if (j < 0) return;
            HapticFeedback.selectionClick();
            setState(() {
              _drag = order[j];
              _dragStart = List.of(order);
              _order = order;
            });
          },
          onPanUpdate: (d) {
            final id = _drag;
            if (id == null) return;
            final to = placeFor(d.localPosition);
            final from = _order.indexOf(id);
            if (from < 0 || to == from) return;
            setState(() {
              _order = List.of(_order)
                ..removeAt(from)
                ..insert(to, id);
            });
          },
          onPanEnd: (_) => _drop(),
          onPanCancel: _drop,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      );
    });
  }

  void _drop() {
    if (_drag == null) return;
    final changed = _dragStart == null || _dragStart!.length != _order.length || [for (var i = 0; i < _order.length; i++) _order[i] != _dragStart![i]].any((x) => x);
    setState(() => _drag = null);
    if (changed) _g({'t': 'pou_order', 'ids': _order});
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t.toUpperCase(), style: Pb.t(12, weight: 600, color: Pb.muted).copyWith(letterSpacing: 1)),
      );
}
