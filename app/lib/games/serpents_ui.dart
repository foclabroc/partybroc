import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'oie_ui.dart' show OieDie;

// =================================================================== plateau « carton »

// bas → haut / tête → queue (mêmes valeurs que server/src/games/serpents.js)
const snkLadders = {4: 25, 8: 30, 13: 46, 33: 49, 42: 63, 50: 69, 62: 81, 74: 92};
const snkSnakes = {27: 5, 40: 3, 43: 18, 54: 31, 66: 45, 76: 58, 89: 53, 99: 41};

const _ink = Color(0xFF3A2A1C);
const _cream = Color(0xFFFFF6E6);
const _soft = Color(0xFFE5CFA8);
const _panel = Color(0xFF4A3726);
const _panel2 = Color(0xFF5A4430);
const _red = Color(0xFFD9472B);

/// Fond (TV et téléphone)
const snkBg = BoxDecoration(
  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A2A1C), Color(0xFF2B2018)]),
);

const _cellA = Color(0xFFF6E7C8);
const _cellB = Color(0xFFEBD5A8);
const _rowTints = [
  Color(0xFFFFB3B3), Color(0xFFFFD49A), Color(0xFFFFF0A0), Color(0xFFC9F0A8), Color(0xFFA8E6E0),
  Color(0xFFB8CCFF), Color(0xFFD9C2FF), Color(0xFFFFC2E2), Color(0xFFFFD49A), Color(0xFFC9F0A8),
];
const _snakeColors = [
  (Color(0xFF2E9E4F), Color(0xFF9BE15D)),
  (Color(0xFFD9472B), Color(0xFFFFB24D)),
  (Color(0xFF6B4FD9), Color(0xFFC3B5FF)),
  (Color(0xFF1E7FA8), Color(0xFF7FD8FF)),
];

/// Taille d'une case du plateau (10 × 10)
const double _c = 96;
const double snkBoardSize = _c * 10;

/// Centre de la case n (1 à 100), en serpentin depuis le bas à gauche
Offset snkCenter(int n) {
  n = n.clamp(1, 100);
  final r = (n - 1) ~/ 10, k = (n - 1) % 10;
  final col = r.isOdd ? 9 - k : k;
  return Offset(col * _c + _c / 2, (9 - r) * _c + _c / 2);
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFB89B6A);
    for (var n = 1; n <= 100; n++) {
      final r = (n - 1) ~/ 10, k = (n - 1) % 10;
      final col = r.isOdd ? 9 - k : k;
      final rect = Rect.fromLTWH(col * _c, (9 - r) * _c, _c, _c);
      final alt = (r + col).isOdd;
      canvas.drawRect(rect, Paint()..color = alt ? _rowTints[r] : _cellB);
      if (!alt) canvas.drawRect(rect.deflate(6), Paint()..color = _cellA.withValues(alpha: .5));
      canvas.drawRect(rect.deflate(1), grid);
      final special = n == 1 || n == 100;
      if (special) canvas.drawRect(rect.deflate(4), Paint()..color = _red);
      final tp = TextPainter(
        text: TextSpan(
          text: n == 1 ? 'DÉPART' : (n == 100 ? '100' : '$n'),
          style: Pb.t(special ? (n == 1 ? 19 : 30) : 24, weight: 700, color: special ? _cream : _ink.withValues(alpha: .8)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.topLeft + const Offset(8, 6));
      if (n == 100) {
        final f = TextPainter(text: const TextSpan(text: '🏁', style: TextStyle(fontSize: 34)), textDirection: TextDirection.ltr)..layout();
        f.paint(canvas, rect.bottomRight - Offset(f.width + 8, f.height + 4));
      }
    }
    for (final e in snkLadders.entries) {
      _ladder(canvas, snkCenter(e.key), snkCenter(e.value));
    }
    var i = 0;
    for (final e in snkSnakes.entries) {
      _snake(canvas, snkCenter(e.key), snkCenter(e.value), _snakeColors[i++ % _snakeColors.length]);
    }
  }

  void _ladder(Canvas canvas, Offset a, Offset b) {
    final d = b - a;
    final len = d.distance;
    final n = Offset(-d.dy / len, d.dx / len) * 16;
    Paint line(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    final shadow = line(const Color(0x66000000), 12);
    for (final m in [1.0, -1.0]) {
      canvas.drawLine(a + n * m + const Offset(4, 6), b + n * m + const Offset(4, 6), shadow);
    }
    final steps = math.max(3, (len / 34).round());
    final rung = line(const Color(0xFFB07A44), 7);
    for (var k = 1; k < steps; k++) {
      final c = a + d * (k / steps);
      canvas.drawLine(c + n, c - n, rung);
    }
    final rail = line(const Color(0xFF8A5A2B), 9);
    for (final m in [1.0, -1.0]) {
      canvas.drawLine(a + n * m, b + n * m, rail);
    }
  }

  void _snake(Canvas canvas, Offset head, Offset tail, (Color, Color) colors) {
    final d = tail - head;
    final len = d.distance;
    final nrm = Offset(-d.dy / len, d.dx / len);
    const steps = 60;
    final waves = math.max(1.5, len / 130);
    final amp = math.min(38.0, len / 7);
    final pts = <Offset>[
      for (var i = 0; i <= steps; i++)
        () {
          final t = i / steps;
          final w = math.sin(t * math.pi * 2 * waves) * amp * math.sin(math.min(1, t * 1.6) * math.pi / 2);
          return head + d * t + nrm * w;
        }(),
    ];
    final p = Paint()..strokeCap = StrokeCap.round;
    for (final shadow in [true, false]) {
      for (var i = steps; i > 0; i--) {
        final t = i / steps;
        final w = 23 - t * 16;
        p
          ..color = shadow ? const Color(0x55000000) : ((i % 8 < 4) ? colors.$1 : colors.$2)
          ..strokeWidth = shadow ? w + 4 : w;
        final o = shadow ? const Offset(3, 4) : Offset.zero;
        canvas.drawLine(pts[i - 1] + o, pts[i] + o, p);
      }
    }
    // Tête
    final ang = math.atan2(pts[0].dy - pts[3].dy, pts[0].dx - pts[3].dx);
    canvas.save();
    canvas.translate(pts[0].dx, pts[0].dy);
    canvas.rotate(ang);
    canvas.drawOval(Rect.fromCenter(center: const Offset(3, 0), width: 44, height: 34), Paint()..color = colors.$1);
    final tongue = Paint()
      ..color = const Color(0xFFFF3B5C)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(23, 0)
        ..lineTo(37, 0)
        ..lineTo(43, -6)
        ..moveTo(37, 0)
        ..lineTo(43, 6),
      tongue,
    );
    for (final y in [-9.0, 9.0]) {
      canvas.drawCircle(Offset(9, y), 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(11, y), 3.3, Paint()..color = const Color(0xFF17102B));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Le plateau avec les pions (photos de profil). Le pion qui vient de jouer
/// avance case par case, puis monte l'échelle ou glisse sur le serpent.
class SnkBoardView extends StatefulWidget {
  const SnkBoardView({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  State<SnkBoardView> createState() => _SnkBoardViewState();
}

class _SnkBoardViewState extends State<SnkBoardView> {
  final _shown = <String, int>{};
  final _dur = <String, int>{};
  int _seq = 0;
  int _token = 0;

  Map<String, int> _positions() => {
        for (final p in (widget.live['players'] as List? ?? const []))
          (p as Map)['pid'] as String: (p['pos'] as num).toInt(),
      };

  @override
  void initState() {
    super.initState();
    _shown.addAll(_positions());
    _seq = widget.live.i('seq');
  }

  @override
  void didUpdateWidget(covariant SnkBoardView old) {
    super.didUpdateWidget(old);
    final seq = widget.live.i('seq');
    final e = widget.live['event'];
    if (seq != _seq && e is Map) {
      _seq = seq;
      _play(e);
    }
    // Les autres (et ce qui a pu être manqué) : à leur place
    final moving = e is Map ? e['pid'] : null;
    for (final MapEntry(:key, :value) in _positions().entries) {
      if (key != moving || !_shown.containsKey(key)) _shown[key] = value;
    }
  }

  Future<void> _play(Map e) async {
    final token = ++_token;
    final pid = e['pid'] as String;
    final step = widget.live.i('stepMs', 280);
    final slide = widget.live.i('slideMs', 1300);
    final path = [for (final n in (e['path'] as List? ?? const [])) (n as num).toInt()];
    for (final n in path) {
      if (!mounted || token != _token) return;
      setState(() {
        _shown[pid] = n;
        _dur[pid] = (step * .85).round();
      });
      await Future<void>.delayed(Duration(milliseconds: step));
    }
    final to = (e['to'] as num).toInt();
    if (e['kind'] != null) await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || token != _token) return;
    setState(() {
      _shown[pid] = to;
      _dur[pid] = slide;
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final current = widget.live.s('current');
    final pids = [for (final p in (widget.live['players'] as List? ?? const [])) (p as Map)['pid'] as String]
      // Le joueur en cours au-dessus des autres
      ..sort((a, b) => (a == current ? 1 : 0) - (b == current ? 1 : 0));
    // Plusieurs pions sur la même case : en cercle
    final byCell = <int, List<String>>{};
    for (final pid in pids) {
      (byCell[_shown[pid] ?? 1] ??= []).add(pid);
    }
    final pawns = <Widget>[];
    for (final pid in pids) {
      final pv = room.player(pid);
      if (pv == null) continue;
      final n = _shown[pid] ?? 1;
      final group = byCell[n]!;
      var c = snkCenter(n);
      if (group.length > 1) {
        final a = group.indexOf(pid) / group.length * math.pi * 2 - math.pi / 2;
        c += Offset(math.cos(a), math.sin(a)) * 22;
      }
      final now = pid == current;
      final s = now ? 72.0 : 58.0;
      pawns.add(AnimatedPositioned(
        key: ValueKey(pid),
        duration: Duration(milliseconds: _dur[pid] ?? 600),
        curve: (_dur[pid] ?? 0) > 600 ? Curves.easeInOutCubic : Curves.easeOut,
        left: c.dx - s / 2,
        top: c.dy + 26 - 10 - s,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (now) BoxShadow(color: Pb.yellow.withValues(alpha: .95), blurRadius: 18, spreadRadius: 3),
                const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6)),
              ],
            ),
            child: PbAvatar(size: s, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
          ),
          CustomPaint(size: const Size(16, 10), painter: _PinTip(Pb.playerColor(pv.color))),
        ]),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF8A5A2B),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 40, offset: Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: SizedBox(
          width: snkBoardSize,
          height: snkBoardSize,
          child: Stack(clipBehavior: Clip.none, children: [
            const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _BoardPainter()))),
            ...pawns,
          ]),
        ),
      ),
    );
  }
}

class _PinTip extends CustomPainter {
  const _PinTip(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTip old) => old.color != color;
}

List<String> _msgs(Map<String, dynamic> live) {
  final e = live['event'];
  if (e is! Map) return const [];
  return [for (final m in (e['msgs'] as List? ?? const [])) m as String];
}

// =================================================================== TV

class SnkTv extends StatelessWidget {
  const SnkTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🐍',
        title: 'Serpents et échelles',
        sub: live['exact'] == false ? 'Le premier sur la case 100 gagne !' : 'Le premier sur la case 100 gagne… en tombant pile !',
        rules: [
          'Chacun lance le dé sur son téléphone, à son tour.',
          'Au pied d’une échelle, on monte. Sur la tête d’un serpent, on redescend.',
          'Un 6 : on rejoue !',
          if (live['exact'] != false) 'Pour finir, il faut tomber pile sur 100, sinon on recule du surplus.',
        ],
        live: live,
      );
    }
    return DecoratedBox(
      decoration: snkBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 55, 56, 55),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SnkBoardView(room: room, live: live),
          const SizedBox(width: 44),
          Expanded(child: _side()),
        ]),
      ),
    );
  }

  Widget _side() {
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final die = live['die'] is num ? (live['die'] as num).toInt() : null;
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map]
      ..sort((a, b) => (b['pos'] as num).compareTo(a['pos'] as num));
    final ph = live.phase;
    final msgs = _msgs(live);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Serpents et échelles', style: Pb.t(40, weight: 700, color: _cream)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          if (cur != null) ...[
            PbAvatar(size: 84, emoji: cur.emoji, color: cur.color, photoPath: cur.photo),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Au tour de', style: Pb.t(24, color: _soft)),
                Text(cur.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(46, weight: 700, color: Pb.yellow)),
              ]),
            ),
          ] else
            const Spacer(),
          OieDie(value: ph == 'turn' ? null : die, size: 104, angle: -.08),
        ]),
      ),
      if (ph == 'turn') ...[
        const SizedBox(height: 14),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 10),
      ],
      const SizedBox(height: 18),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(live.i('seq')),
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(color: msgs.isEmpty ? _panel2 : _cream, borderRadius: BorderRadius.circular(22)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (msgs.isEmpty)
              Text('Premier sur la case 100 !', style: Pb.t(30, weight: 600, color: _cream))
            else
              for (final (i, m) in msgs.indexed)
                Text(m, style: Pb.t(i == msgs.length - 1 ? 32 : 26, weight: i == msgs.length - 1 ? 700 : 600, color: _ink)),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      // Les joueurs, du plus avancé au moins avancé
      Expanded(
        child: ClipRect(
          child: Column(children: [
            for (final p in players)
              if (room.player(p['pid'] as String) case final pv?)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p['pid'] == current ? Pb.yellow : Colors.transparent, width: 3),
                  ),
                  child: Row(children: [
                    PbAvatar(size: players.length > 8 ? 34 : 44, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
                    const SizedBox(width: 14),
                    Expanded(child: Text(pv.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(28, weight: 600, color: _cream))),
                    Text(p['pos'] == 1 ? 'Départ' : 'case ${p['pos']}', style: Pb.t(30, weight: 700, color: Pb.yellow)),
                  ]),
                ),
          ]),
        ),
      ),
      Wrap(spacing: 26, runSpacing: 6, children: [
        for (final t in ['🪜 on monte', '🐍 on redescend', '🎲 un 6 : on rejoue', if (live['exact'] != false) '🎯 pile sur 100'])
          Text(t, style: Pb.t(22, color: _soft)),
      ]),
    ]);
  }
}

// =================================================================== téléphone

class SnkPlay extends StatelessWidget {
  const SnkPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
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
      'intro' => const PhoneCenter(emoji: '🐍', title: 'Serpents et échelles', sub: 'Lance le dé à ton tour. Monte aux échelles, évite les serpents !'),
      'podium' => phoneRank(you),
      _ => you?['inGame'] == true ? _game() : const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !'),
    };
    return DecoratedBox(
      decoration: snkBg,
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
    final pos = you.yi('pos') ?? 1;
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final die = live['die'] is num ? (live['die'] as num).toInt() : null;
    final ph = live.phase;

    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(pos == 1 ? 'Case départ' : 'Case $pos', style: Pb.t(24, weight: 700, color: Pb.yellow)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(value: pos / 100, minHeight: 10, color: _red, backgroundColor: Colors.black26),
      ),
    ]);

    final Widget middle;
    if (you.yb('myTurn')) {
      middle = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('À toi de jouer !', style: Pb.t(30, weight: 700, color: Pb.yellow)),
        const SizedBox(height: 26),
        const OieDie(value: null, size: 130, angle: -.1),
        const SizedBox(height: 22),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 6),
      ]);
    } else {
      middle = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (cur != null) ...[
          PbAvatar(size: 70, emoji: cur.emoji, color: cur.color, photoPath: cur.photo),
          const SizedBox(height: 8),
          Text(current == you?['pid'] ? 'C’est toi !' : 'À ${cur.name} de jouer', textAlign: TextAlign.center, style: Pb.t(22, weight: 700, color: _cream)),
        ],
        if (die != null && ph != 'turn') ...[
          const SizedBox(height: 18),
          OieDie(value: die, size: 80, angle: -.08),
        ],
        const SizedBox(height: 18),
        for (final m in _msgs(live)) Text(m, textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: _cream)),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Expanded(child: middle),
        if (you.yb('myTurn'))
          SizedBox(
            height: 80,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Pb.yellow, foregroundColor: const Color(0xFF17102B)),
              onPressed: () {
                HapticFeedback.heavyImpact();
                _g({'t': 'snk_roll'});
              },
              child: Text('🎲 Lancer le dé', style: Pb.t(28, weight: 700, color: const Color(0xFF17102B))),
            ),
          ),
      ]),
    );
  }
}
