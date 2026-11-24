import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'oie_ui.dart' show OieDie;

// =================================================================== plateau
// Plateau français 15 × 15, style « bois » choisi sur la maquette « Petits chevaux PartyBroc » :
// Vert en haut à gauche, Jaune en haut à droite, Rouge en bas à droite, Bleu en bas à gauche.
// Mêmes valeurs que server/src/games/chevaux.js.

const double _c = 64;
const double chvBoardSize = _c * 15;
const chvStart = [0, 14, 28, 42];
const chvLast = 55;
const chvEnd = 62;
const chvNames = ['Vert', 'Jaune', 'Rouge', 'Bleu'];
const chvColors = [Color(0xFF2FA35A), Color(0xFFF2B705), Color(0xFFE0413C), Color(0xFF2F6BFF)];
const chvDark = [Color(0xFF17602F), Color(0xFF9A7300), Color(0xFF8F1F1F), Color(0xFF173C99)];

const _wood = Color(0xFFD8A466);
const _edge = Color(0xFF7A4A1C);
const _empty = Color(0xFFF6E7C8);
const _ink = Color(0xFF5B3613);
const _cream = Color(0xFFFFF6E6);
const _soft = Color(0xFFE5CFA8);
const _panel = Color(0xFF4A3726);
const _panel2 = Color(0xFF5A4430);

const chvBg = BoxDecoration(
  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A2A1C), Color(0xFF2B2018)]),
);

/// Les 56 cases du parcours (ligne, colonne), départ des verts en (6, 0)
final List<(int, int)> chvTrack = () {
  final t = <(int, int)>[];
  for (var c = 0; c <= 5; c++) {
    t.add((6, c));
  }
  t.add((6, 6));
  for (var r = 5; r >= 0; r--) {
    t.add((r, 6));
  }
  t.add((0, 7));
  for (var r = 0; r <= 5; r++) {
    t.add((r, 8));
  }
  t.add((6, 8));
  for (var c = 9; c <= 14; c++) {
    t.add((6, c));
  }
  t.add((7, 14));
  for (var c = 14; c >= 9; c--) {
    t.add((8, c));
  }
  t.add((8, 8));
  for (var r = 9; r <= 14; r++) {
    t.add((r, 8));
  }
  t.add((14, 7));
  for (var r = 14; r >= 9; r--) {
    t.add((r, 6));
  }
  t.add((8, 6));
  for (var c = 5; c >= 0; c--) {
    t.add((8, c));
  }
  t.add((7, 0));
  return t;
}();

/// Escalier de chaque couleur : marches 1 à 6
(int, int) _stair(int color, int i) => switch (color) {
      0 => (7, 1 + i),
      1 => (1 + i, 7),
      2 => (7, 13 - i),
      _ => (13 - i, 7),
    };

const _stables = [(0, 0), (0, 9), (9, 9), (9, 0)];
const _slots = [(1.3, 1.3), (1.3, 3.7), (3.7, 1.3), (3.7, 3.7)];

Offset _cell(int r, int c) => Offset(c * _c + _c / 2, r * _c + _c / 2);

/// Centre d'un cheval (couleur, numéro, position relative : -1 écurie, 0-55 parcours, 56-61 marches, 62 centre)
Offset chvCenter(int color, int h, int rel, int nh) {
  if (rel < 0) {
    final (sr, sc) = _stables[color];
    final (a, b) = _slots[nh == 2 ? (h == 0 ? 0 : 3) : h % 4];
    return Offset((sc + b + .5) * _c, (sr + a + .5) * _c);
  }
  if (rel >= chvEnd) {
    final dir = [const Offset(-1, 0), const Offset(0, -1), const Offset(1, 0), const Offset(0, 1)][color];
    final side = Offset(-dir.dy, dir.dx) * ((h - 1.5) * 9);
    return Offset(7.5 * _c, 7.5 * _c) + dir * 18 + side;
  }
  if (rel > chvLast) {
    final (r, c) = _stair(color, rel - chvLast - 1);
    return _cell(r, c);
  }
  final (r, c) = chvTrack[(chvStart[color] + rel) % 56];
  return _cell(r, c);
}

Path _horseHead() => Path()
  ..moveTo(-26, 34)
  ..quadraticBezierTo(-30, 6, -20, -10)
  ..quadraticBezierTo(-14, -24, -2, -30)
  ..lineTo(2, -42)
  ..lineTo(8, -30)
  ..quadraticBezierTo(22, -26, 30, -10)
  ..quadraticBezierTo(36, 2, 30, 10)
  ..quadraticBezierTo(24, 14, 16, 8)
  ..quadraticBezierTo(10, 4, 6, 10)
  ..quadraticBezierTo(4, 24, 10, 34)
  ..close();

class _BoardPainter extends CustomPainter {
  const _BoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = chvBoardSize;
    canvas.drawRect(Offset.zero & Size(s, s), Paint()..color = _wood);
    // Veines du bois
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0x22000000);
    for (var y = 10.0; y < s; y += 19) {
      final p = Path()..moveTo(0, y);
      for (var x = 0.0; x < s; x += 96) {
        p.quadraticBezierTo(x + 24, y - 5 + (x % 3) * 2, x + 48, y);
        p.quadraticBezierTo(x + 72, y + 5, x + 96, y);
      }
      canvas.drawPath(p, grain);
    }
    canvas.drawRect(
      const Rect.fromLTWH(5, 5, chvBoardSize - 10, chvBoardSize - 10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = _edge,
    );
    // Écuries
    for (var p = 0; p < 4; p++) {
      final (r, c) = _stables[p];
      final rect = Rect.fromLTWH(c * _c + 22, r * _c + 22, 6 * _c - 44, 6 * _c - 44);
      canvas.drawRect(rect.inflate(7), Paint()..color = Colors.white);
      canvas.drawRect(
        rect.inflate(7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = chvDark[p],
      );
      canvas.drawRect(rect, Paint()..color = chvColors[p]);
      _medallion(canvas, rect.center, 100);
      for (final (a, b) in _slots) {
        final o = Offset((c + b + .5) * _c, (r + a + .5) * _c);
        canvas.drawCircle(o, 25, Paint()..color = const Color(0x55FFFFFF));
        canvas.drawCircle(
          o,
          25,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = Colors.white,
        );
      }
    }
    // Parcours : 56 ronds, de la couleur de l'écurie voisine ; flèche devant chaque escalier
    for (var i = 0; i < 56; i++) {
      final (r, c) = chvTrack[i];
      final o = _cell(r, c);
      if (i % 14 == 13) {
        final owner = (i ~/ 14 + 1) % 4;
        final rect = Rect.fromCenter(center: o, width: 50, height: 50);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), Paint()..color = _empty);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(7)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = _ink,
        );
        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(const [math.pi / 2, math.pi, -math.pi / 2, 0.0][owner]);
        canvas.drawPath(
          Path()
            ..moveTo(0, -15)
            ..lineTo(12, 2)
            ..lineTo(4, 2)
            ..lineTo(4, 15)
            ..lineTo(-4, 15)
            ..lineTo(-4, 2)
            ..lineTo(-12, 2)
            ..close(),
          Paint()..color = chvDark[owner],
        );
        canvas.restore();
        continue;
      }
      final q = i ~/ 14;
      final start = chvStart.contains(i);
      canvas.drawCircle(o + const Offset(2, 3), start ? 28 : 25, Paint()..color = const Color(0x33000000));
      canvas.drawCircle(o, start ? 28 : 25, Paint()..color = chvColors[q]);
      canvas.drawCircle(
        o,
        start ? 28 : 25,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = start ? 6 : 2.5
          ..color = start ? Colors.white : chvDark[q],
      );
      if (start) {
        canvas.drawCircle(
          o,
          34,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = chvColors[q],
        );
      }
    }
    // Escaliers : marches numérotées 1 à 6
    for (var p = 0; p < 4; p++) {
      for (var i = 0; i < 6; i++) {
        final (r, c) = _stair(p, i);
        final rect = Rect.fromLTWH(c * _c + 3, r * _c + 3, _c - 6, _c - 6);
        canvas.drawRect(rect, Paint()..color = chvColors[p]);
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = Colors.white,
        );
        final tp = TextPainter(
          text: TextSpan(text: '${i + 1}', style: Pb.t(34, weight: 700, color: Colors.white)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // Centre : rose des vents
    final ctr = Offset(7.5 * _c, 7.5 * _c);
    canvas.drawCircle(ctr, 30, Paint()..color = _empty);
    canvas.drawCircle(
      ctr,
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _ink,
    );
    for (var p = 0; p < 4; p++) {
      canvas.save();
      canvas.translate(ctr.dx, ctr.dy);
      canvas.rotate((p * 90 - 45) * math.pi / 180);
      final petal = Path()
        ..moveTo(0, -27)
        ..lineTo(8, 0)
        ..lineTo(0, 8)
        ..lineTo(-8, 0)
        ..close();
      canvas.drawPath(petal, Paint()..color = chvColors[p]);
      canvas.drawPath(
        petal,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _ink,
      );
      canvas.restore();
    }
    canvas.drawCircle(ctr, 5, Paint()..color = _ink);
  }

  // Tête de cheval peinte dans une couronne de laurier
  void _medallion(Canvas canvas, Offset o, double r) {
    canvas.drawCircle(o, r, Paint()..color = _empty);
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x33000000),
    );
    final leaf = Paint()..color = const Color(0xFF3E8F3A);
    for (var i = 0; i < 14; i++) {
      for (final t in [math.pi * (.62 + i * .06), math.pi * (.38 - i * .06)]) {
        final p = o + Offset(math.cos(t), math.sin(t)) * (r - 15);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(t + math.pi / 2);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 20, height: 9), leaf);
        canvas.restore();
      }
    }
    canvas.save();
    canvas.translate(o.dx - 7, o.dy + 3);
    canvas.scale(r / 52);
    final head = _horseHead();
    canvas.drawPath(head, Paint()..color = const Color(0xFF8A4B22));
    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF4A2410),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-2, -30)
        ..quadraticBezierTo(-12, -20, -16, -2)
        ..quadraticBezierTo(-20, 14, -22, 34),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3A1C0C),
    );
    canvas.drawCircle(const Offset(12, -14), 3.5, Paint()..color = const Color(0xFF1A0D05));
    canvas.drawCircle(const Offset(26, 4), 2, Paint()..color = const Color(0xFF1A0D05));
    canvas.drawPath(
      Path()
        ..moveTo(6, -20)
        ..quadraticBezierTo(14, -22, 18, -16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF4E3C8),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Un cheval (pièce d'échecs) de la couleur de son équipe, avec son numéro
class ChvHorse extends StatelessWidget {
  const ChvHorse({super.key, required this.color, required this.number, this.size = 60});
  final int color, number;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _HorsePainter(color, number)),
      );
}

class _HorsePainter extends CustomPainter {
  const _HorsePainter(this.color, this.number);
  final int color, number;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 34);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 13), width: 28, height: 8), Paint()..color = const Color(0x55000000));
    final body = Path()
      ..moveTo(-12, 12)
      ..quadraticBezierTo(-12, 4, -8, 2)
      ..lineTo(-6, -4)
      ..quadraticBezierTo(-9, -8, -8, -12)
      ..quadraticBezierTo(-4, -18, 3, -17)
      ..lineTo(6, -20)
      ..lineTo(7, -15)
      ..quadraticBezierTo(12, -12, 12, -6)
      ..quadraticBezierTo(12, -2, 9, -1)
      ..lineTo(3, -3)
      ..quadraticBezierTo(1, 2, 6, 6)
      ..quadraticBezierTo(10, 9, 10, 12)
      ..close();
    canvas.drawPath(body, Paint()..color = chvColors[color]);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const RadialGradient(center: Alignment(-.3, -.5), radius: .8, colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)])
            .createShader(const Rect.fromLTWH(-12, -20, 24, 32)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = chvDark[color],
    );
    canvas.drawCircle(const Offset(4, -11), 1.4, Paint()..color = Colors.white);
    // Numéro sur le socle
    canvas.drawCircle(const Offset(-1, 7), 5.2, Paint()..color = Colors.white);
    final tp = TextPainter(
      text: TextSpan(text: '$number', style: Pb.t(8, weight: 700, color: chvDark[color])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-1 - tp.width / 2, 7 - tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HorsePainter old) => old.color != color || old.number != number;
}

class _Team {
  _Team(Map m)
      : color = (m['c'] as num).toInt(),
        pids = [for (final p in (m['pids'] as List? ?? const [])) p as String],
        horses = [for (final h in (m['horses'] as List? ?? const [])) (h as num).toInt()],
        done = (m['done'] as num?)?.toInt() ?? 0;
  final int color, done;
  final List<String> pids;
  final List<int> horses;
}

List<_Team> _teams(Map<String, dynamic> live) => [for (final t in (live['teams'] as List? ?? const [])) _Team(t as Map)];

/// Le plateau avec les chevaux qui avancent case par case (TV, et en petit sur le téléphone)
class ChvBoardView extends StatefulWidget {
  const ChvBoardView({super.key, required this.room, required this.live, this.avatars = true});
  final RoomView room;
  final Map<String, dynamic> live;
  final bool avatars;

  @override
  State<ChvBoardView> createState() => _ChvBoardViewState();
}

class _ChvBoardViewState extends State<ChvBoardView> with SingleTickerProviderStateMixin {
  final _shown = <String, int>{};
  final _busy = <String>{};
  int _seq = 0, _token = 0;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  Map<String, int> _positions() => {
        for (final (t, team) in _teams(widget.live).indexed)
          for (final (h, r) in team.horses.indexed) '$t-$h': r,
      };

  @override
  void initState() {
    super.initState();
    _shown.addAll(_positions());
    _seq = widget.live.i('seq');
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChvBoardView old) {
    super.didUpdateWidget(old);
    final seq = widget.live.i('seq');
    final e = widget.live['event'];
    if (seq != _seq && e is Map) {
      _seq = seq;
      _play(e);
    }
    for (final MapEntry(:key, :value) in _positions().entries) {
      if (!_busy.contains(key) || !_shown.containsKey(key)) _shown[key] = value;
    }
  }

  Future<void> _play(Map e) async {
    final h = e['h'];
    if (h == null) return;
    final token = ++_token;
    final key = '${e['t']}-$h';
    final eat = e['eat'] is Map ? '${(e['eat'] as Map)['t']}-${(e['eat'] as Map)['h']}' : null;
    final path = [for (final n in (e['path'] as List? ?? const [])) (n as num).toInt()];
    final from = (e['from'] as num?)?.toInt() ?? -1;
    _busy
      ..clear()
      ..add(key);
    if (eat != null) _busy.add(eat);
    final eatPos = eat == null ? null : _lastBeforeEat(eat);
    setState(() {
      _shown[key] = from;
      if (eat != null && eatPos != null) _shown[eat] = eatPos;
    });
    await Future<void>.delayed(Duration(milliseconds: (e['wait'] as num?)?.toInt() ?? 0));
    final step = widget.live.i('stepMs', 260);
    for (final n in path) {
      if (!mounted || token != _token) return;
      setState(() => _shown[key] = n);
      await Future<void>.delayed(Duration(milliseconds: step));
    }
    if (eat != null) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted || token != _token) return;
      setState(() => _shown[eat] = -1);
    }
    _busy.clear();
  }

  // Le cheval mangé était sur la case d'arrivée du cheval qui mange (même case du parcours)
  int? _lastBeforeEat(String eat) {
    final e = widget.live['event'] as Map;
    final teams = _teams(widget.live);
    final path = [for (final n in (e['path'] as List? ?? const [])) (n as num).toInt()];
    if (path.isEmpty) return null;
    final mover = teams[(e['t'] as num).toInt()].color;
    final cell = (chvStart[mover] + path.last) % 56;
    final vt = int.parse(eat.split('-')[0]);
    final vc = teams[vt].color;
    return (cell - chvStart[vc] + 56) % 56;
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final teams = _teams(live);
    final nh = live.i('nh', 4);
    final cur = live['current'] is num ? (live['current'] as num).toInt() : null;
    final picks = {
      if (live.phase == 'pick') for (final o in (live['options'] as List? ?? const [])) ((o as Map)['h'] as num).toInt(),
    };
    // Regroupe les chevaux par case pour les décaler
    final spots = <String, List<String>>{};
    final where = <String, Offset>{};
    for (final (t, team) in teams.indexed) {
      for (var h = 0; h < team.horses.length; h++) {
        final k = '$t-$h';
        final o = chvCenter(team.color, h, _shown[k] ?? team.horses[h], nh);
        where[k] = o;
        (spots['${o.dx.round()},${o.dy.round()}'] ??= []).add(k);
      }
    }
    final pieces = <Widget>[];
    final order = where.keys.toList()..sort((a, b) => (a.startsWith('$cur-') ? 1 : 0) - (b.startsWith('$cur-') ? 1 : 0));
    for (final k in order) {
      final t = int.parse(k.split('-')[0]), h = int.parse(k.split('-')[1]);
      var o = where[k]!;
      final group = spots['${o.dx.round()},${o.dy.round()}']!;
      if (group.length > 1) o += Offset((group.indexOf(k) - (group.length - 1) / 2) * 16, -(group.indexOf(k) - (group.length - 1) / 2) * 5);
      final hl = t == cur && picks.contains(h);
      const s = 62.0;
      pieces.add(AnimatedPositioned(
        key: ValueKey(k),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        left: o.dx - s / 2,
        top: o.dy - s / 2 - 6,
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (hl)
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => Container(
                  width: 58 + _pulse.value * 18,
                  height: 58 + _pulse.value * 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Pb.yellow.withValues(alpha: .25), border: Border.all(color: Pb.yellow, width: 6)),
                ),
              ),
            ChvHorse(color: teams[t].color, number: h + 1, size: s),
          ]),
        ),
      ));
    }
    // Avatars des joueurs dans le coin de leur écurie
    final avatars = <Widget>[];
    if (widget.avatars) {
      for (final team in teams) {
        final pv = widget.room.player(team.pids.isEmpty ? '' : team.pids.first);
        if (pv == null) continue;
        final (r, c) = _stables[team.color];
        final left = team.color == 0 || team.color == 3;
        final top = team.color < 2;
        final x = (c + (left ? .55 : 5.45)) * _c, y = (r + (top ? .55 : 5.45)) * _c;
        avatars.add(Positioned(
          left: x - 30,
          top: y - 30,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)]),
              child: PbAvatar(size: 60, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
            ),
            if (team.pids.length > 1)
              Positioned(
                right: -10,
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: chvDark[team.color], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 2)),
                  child: Text('+${team.pids.length - 1}', style: Pb.t(18, weight: 700, color: Colors.white)),
                ),
              ),
          ]),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: chvBoardSize,
          height: chvBoardSize,
          child: Stack(clipBehavior: Clip.none, children: [
            const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _BoardPainter()))),
            ...avatars,
            ...pieces,
          ]),
        ),
      ),
    );
  }
}

List<String> _msgs(Map<String, dynamic> live) {
  final e = live['event'];
  if (e is! Map) return const [];
  return [for (final m in (e['msgs'] as List? ?? const [])) m as String];
}

/// Libellé d'un coup proposé
(String, String) chvMoveLabel(Map o, bool stairs) {
  final from = (o['from'] as num).toInt(), to = (o['to'] as num).toInt();
  if (from < 0) return ('Sortir de l’écurie', 'sur ta case de départ');
  if (to >= chvEnd) return ('Entrer au centre 🏆', 'il est arrivé !');
  if (to > chvLast) return (stairs ? 'Monter sur la marche ${to - chvLast}' : 'Avancer de ${to - from}', 'escalier, marche ${to - chvLast}');
  final eat = o['eat'] == true;
  return ('Avancer de ${to - from}', eat ? 'mange un cheval !' : (to == chvLast ? 'pile devant ton escalier' : 'encore ${chvLast - to} cases avant l’escalier'));
}

// =================================================================== TV

class ChvTv extends StatelessWidget {
  const ChvTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🐴',
        title: 'Petits chevaux',
        sub: 'La première couleur à rentrer tous ses chevaux gagne !',
        rules: [
          'Il faut un 6 pour sortir un cheval de l’écurie. Un 6 : on rejoue !',
          'Tombe pile sur un cheval adverse : il retourne à son écurie.',
          if (live['stairs'] != false)
            'L’escalier : pile sur la flèche, puis 1, 2… 6 pour monter les marches, et un 6 pour entrer au centre.'
          else
            'L’escalier se monte avec n’importe quel dé, mais il faut tomber pile au centre.',
          if (_teams(live).any((t) => t.pids.length > 1)) 'Une couleur par équipe : vous lancez le dé chacun votre tour.',
        ],
        live: live,
      );
    }
    return DecoratedBox(
      decoration: chvBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 60, 56, 60),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChvBoardView(room: room, live: live),
          const SizedBox(width: 44),
          Expanded(child: _side()),
        ]),
      ),
    );
  }

  Widget _side() {
    final teams = _teams(live);
    final cur = live['current'] is num ? (live['current'] as num).toInt() : null;
    final player = room.player(live.s('player') ?? '');
    final die = live['die'] is num ? (live['die'] as num).toInt() : null;
    final ph = live.phase;
    final msgs = _msgs(live);
    final rolling = ph == 'move' && (live['event'] as Map?)?['wait'] != 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('🐴 Petits chevaux', style: Pb.t(42, weight: 700, color: _cream)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cur == null ? Colors.transparent : chvColors[teams[cur].color], width: 5),
        ),
        child: Row(children: [
          if (player != null && cur != null) ...[
            PbAvatar(size: 84, emoji: player.emoji, color: player.color, photoPath: player.photo),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Au tour des ${chvNames[teams[cur].color]}s', style: Pb.t(24, color: _soft)),
                Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(46, weight: 700, color: Pb.yellow)),
              ]),
            ),
          ] else
            const Spacer(),
          OieDie(value: ph == 'turn' ? null : die, size: 104, angle: -.08, rollKey: rolling || ph == 'pick' ? live.i('rollSeq') : null, rollMs: live.i('diceMs', 1000)),
        ]),
      ),
      if (ph == 'turn' || ph == 'pick') ...[
        const SizedBox(height: 14),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 10),
      ],
      const SizedBox(height: 18),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey('${live.i('seq')}-$ph'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(color: ph == 'move' && msgs.isNotEmpty ? _cream : _panel2, borderRadius: BorderRadius.circular(22)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (ph == 'pick')
              Text('${player?.name ?? '?'} fait $die : quel cheval ?', style: Pb.t(32, weight: 700, color: _cream))
            else if (ph == 'turn')
              Text('${player?.name ?? '?'} lance le dé…', style: Pb.t(32, weight: 600, color: _cream))
            else
              for (final (i, m) in msgs.indexed)
                Text(m, style: Pb.t(i == msgs.length - 1 ? 30 : 25, weight: i == msgs.length - 1 ? 700 : 600, color: _ink)),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Expanded(
        child: ClipRect(
          child: Column(children: [
            for (final (t, team) in teams.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t == cur ? Pb.yellow : Colors.transparent, width: 3),
                ),
                child: Row(children: [
                  Container(width: 18, height: 54, decoration: BoxDecoration(color: chvColors[team.color], borderRadius: BorderRadius.circular(6))),
                  const SizedBox(width: 12),
                  for (final pid in team.pids.take(4))
                    if (room.player(pid) case final pv?)
                      Padding(padding: const EdgeInsets.only(right: 4), child: PbAvatar(size: 44, emoji: pv.emoji, color: pv.color, photoPath: pv.photo)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      team.pids.length == 1 ? (room.player(team.pids.first)?.name ?? '?') : chvNames[team.color],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Pb.t(28, weight: 600, color: _cream),
                    ),
                  ),
                  for (final r in team.horses)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Opacity(
                        opacity: r < 0 ? .35 : 1,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: chvColors[team.color],
                            shape: BoxShape.circle,
                            border: Border.all(color: r >= chvEnd ? Colors.white : chvDark[team.color], width: r >= chvEnd ? 4 : 2),
                          ),
                          child: r >= chvEnd ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                        ),
                      ),
                    ),
                ]),
              ),
          ]),
        ),
      ),
      Wrap(spacing: 26, runSpacing: 6, children: [
        for (final t in ['🎲 un 6 pour sortir', '🔁 un 6 : on rejoue', '💥 on mange en tombant pile', if (live['stairs'] != false) '🪜 escalier 1 → 6'])
          Text(t, style: Pb.t(22, color: _soft)),
      ]),
    ]);
  }
}

// =================================================================== téléphone

class ChvPlay extends StatelessWidget {
  const ChvPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  void _g(Map<String, dynamic> m) => send({'t': 'game_msg', 'm': m});

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🐴', title: 'Petits chevaux', sub: 'Un 6 pour sortir de l’écurie, mange les chevaux des autres et monte l’escalier jusqu’au centre !'),
      'podium' => phoneRank(you),
      _ => you?['inGame'] == true ? _game() : const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !'),
    };
    return DecoratedBox(
      decoration: chvBg,
      child: PhoneGameFrame(
        stepKey: '$ph-${live.i('seq')}-${you.yb('myTurn')}',
        isHost: isHost,
        phase: ph,
        send: send,
        skipLabel: 'Faire passer',
        child: body,
      ),
    );
  }

  Widget _game() {
    final ph = live.phase;
    final color = you.yi('color') ?? 0;
    final teams = _teams(live);
    final mates = [for (final m in (you?['mates'] as List? ?? const [])) room.player(m as String)?.name ?? '?'];
    final player = room.player(live.s('player') ?? '');
    final die = live['die'] is num ? (live['die'] as num).toInt() : null;
    final stairs = live['stairs'] != false;

    final header = Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: chvColors[color], borderRadius: BorderRadius.circular(20)),
        child: Text('Tu joues les ${chvNames[color]}s', style: Pb.t(16, weight: 700, color: Colors.white)),
      ),
      const SizedBox(width: 8),
      if (mates.isNotEmpty) Expanded(child: Text('avec ${mates.join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(14, color: _soft))),
    ]);

    final board = Center(child: SizedBox(width: 300, height: 300, child: FittedBox(child: ChvBoardView(room: room, live: live, avatars: false))));

    final Widget bottom;
    if (you.yb('myTurn') && ph == 'turn') {
      bottom = Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('À toi de jouer !', textAlign: TextAlign.center, style: Pb.t(26, weight: 700, color: Pb.yellow)),
        const SizedBox(height: 8),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 6),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Pb.yellow, foregroundColor: const Color(0xFF17102B)),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _g({'t': 'chv_roll'});
            },
            child: Text('🎲 Lancer le dé', style: Pb.t(28, weight: 700, color: const Color(0xFF17102B))),
          ),
        ),
      ]);
    } else if (you.yb('myTurn') && ph == 'pick') {
      final opts = [for (final o in (live['options'] as List? ?? const [])) o as Map];
      bottom = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Tu as fait $die : quel cheval ?', style: Pb.t(20, weight: 700, color: Pb.yellow))),
          OieDie(value: die, size: 40, angle: -.08),
        ]),
        const SizedBox(height: 6),
        for (final o in opts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: _panel,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _g({'t': 'chv_pick', 'h': o['h']});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: o['eat'] == true ? Pb.pink : _panel2, width: 2.5)),
                  child: Row(children: [
                    ChvHorse(color: color, number: ((o['h'] as num).toInt()) + 1, size: 38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(builder: (_) {
                        final (a, b) = chvMoveLabel(o, stairs);
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Cheval ${(o['h'] as num).toInt() + 1} · $a', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(16, weight: 700, color: _cream)),
                          Text(b, style: Pb.t(13, weight: o['eat'] == true ? 700 : 500, color: o['eat'] == true ? Pb.pink : _soft)),
                        ]);
                      }),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    } else {
      final mine = teams.where((t) => t.color == color).firstOrNull;
      bottom = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (player != null)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PbAvatar(size: 40, emoji: player.emoji, color: player.color, photoPath: player.photo),
            const SizedBox(width: 10),
            Flexible(child: Text(player.pid == you?['pid'] ? 'C’est toi !' : 'À ${player.name} de jouer', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(20, weight: 700, color: _cream))),
            if (die != null && ph != 'turn') ...[const SizedBox(width: 12), OieDie(value: die, size: 40, angle: -.08)],
          ]),
        const SizedBox(height: 8),
        for (final m in _msgs(live).take(3)) Text(m, textAlign: TextAlign.center, maxLines: 2, style: Pb.t(15, weight: 600, color: _cream)),
        const SizedBox(height: 8),
        if (mine != null)
          Text(
            '${mine.horses.where((r) => r < 0).length} à l’écurie · ${mine.horses.where((r) => r >= 0 && r < chvEnd).length} en course · ${mine.done} arrivé${mine.done > 1 ? 's' : ''}',
            style: Pb.t(14, color: _soft),
          ),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        const SizedBox(height: 8),
        board,
        const SizedBox(height: 8),
        Expanded(child: bottom),
      ]),
    );
  }
}
