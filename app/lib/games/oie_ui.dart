import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

// =================================================================== plateau

const _geese = {5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59};
const _defi = {10, 26, 37, 48};

/// Couleur, couleur du texte, nom et règle d'une case spéciale (null = case normale)
({Color bg, Color fg, String label, String rule})? oieSpecial(int n) {
  const dark = Color(0xFF17102B);
  if (_geese.contains(n)) return (bg: const Color(0xFFFFD23F), fg: dark, label: 'Oie', rule: 'rejoue son lancer');
  if (_defi.contains(n)) return (bg: const Color(0xFF4CE38A), fg: dark, label: 'Défi', rule: 'question : ±3 cases');
  return switch (n) {
    6 => (bg: const Color(0xFF3FE0FF), fg: dark, label: 'Pont', rule: 'saute à la 12'),
    19 => (bg: const Color(0xFF8E6BFF), fg: dark, label: 'Hôtel', rule: '2 tours de repos'),
    31 => (bg: const Color(0xFF8E6BFF), fg: dark, label: 'Puits', rule: 'attend un sauveur'),
    42 => (bg: const Color(0xFFFF4FA3), fg: dark, label: 'Labyrinthe', rule: 'retour à la 30'),
    52 => (bg: const Color(0xFF8E6BFF), fg: dark, label: 'Prison', rule: 'attend un sauveur'),
    58 => (bg: const Color(0xFFFF5A5A), fg: dark, label: 'Mort', rule: 'retour au départ'),
    63 => (bg: const Color(0xFFFFD23F), fg: dark, label: 'Arrivée', rule: 'tomber pile sur 63'),
    _ => null,
  };
}

/// Fond « étang » (TV et téléphone)
const oiePond = BoxDecoration(
  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B2B35), Color(0xFF0C2230), Color(0xFF101A33)]),
);

/// Le plateau : 1312 × 832, chemin en spirale (150 px entre deux tours), case 0 = départ
class OieBoard {
  OieBoard._(this.road, this.centers);
  final List<Offset> road; // coins du chemin
  final List<Offset> centers; // centres des cases 0 (départ) à 63

  static const size = Size(1312, 832);
  static final instance = _build();

  static OieBoard _build() {
    const m = 70.0, d = 150.0;
    var l = m, t = m, r = size.width - m, b = size.height - m;
    final pts = <Offset>[Offset(l, b)];
    while (true) {
      pts.addAll([Offset(r, b), Offset(r, t), Offset(l, t)]);
      final nb = b - d;
      if (nb - t < d) break;
      pts.add(Offset(l, nb));
      l += d;
      r -= d;
      t += d;
      b = nb;
      if (r - l < d || b - t < d) break;
      pts.add(Offset(l, b));
    }
    var total = 0.0;
    final at = <double>[0];
    for (var i = 0; i < pts.length - 1; i++) {
      total += (pts[i + 1] - pts[i]).distance;
      at.add(total);
    }
    Offset point(double dist) {
      for (var k = 0; k < pts.length - 1; k++) {
        if (dist <= at[k + 1] || k == pts.length - 2) {
          final len = at[k + 1] - at[k];
          final f = len == 0 ? 0.0 : (dist - at[k]) / len;
          return Offset.lerp(pts[k], pts[k + 1], f)!;
        }
      }
      return pts.last;
    }

    // La case 0 (départ) est au tout début du chemin, les 63 cases ensuite
    final centers = [for (var j = 0; j <= 63; j++) point(total * j / 63)];
    return OieBoard._(pts, centers);
  }
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Ronds dans l'eau
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: .05);
    for (final (c, step) in [(const Offset(1020, 180), 54.0), (const Offset(240, 680), 46.0)]) {
      for (var r = step; r < 700; r += step) {
        canvas.drawCircle(c, r, ring);
      }
    }
    final board = OieBoard.instance;
    final path = Path()..moveTo(board.road.first.dx, board.road.first.dy);
    for (final p in board.road.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    Paint line(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.drawPath(path.shift(const Offset(0, 6)), line(Colors.black.withValues(alpha: .3), 78));
    canvas.drawPath(path, line(const Color(0xFFE9DFC4), 72));
    // pointillés au milieu de l'allée
    final dash = line(const Color(0xFFC7B98F), 3);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 19) {
        final p = metric.getTangentForOffset(d)?.position;
        if (p != null) canvas.drawCircle(p, 1.6, dash..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Le plateau avec les cases et les pions (photos de profil) des joueurs
class OieBoardView extends StatefulWidget {
  const OieBoardView({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  State<OieBoardView> createState() => _OieBoardViewState();
}

class _OieBoardViewState extends State<OieBoardView> {
  // Pion gardé sur sa case de départ pendant que les dés roulent
  final _hold = <String, int>{};
  int _seq = -1;

  @override
  void initState() {
    super.initState();
    _seq = widget.live.i('seq');
  }

  @override
  void didUpdateWidget(covariant OieBoardView old) {
    super.didUpdateWidget(old);
    final seq = widget.live.i('seq');
    final e = widget.live['event'];
    if (seq == _seq) return;
    _seq = seq;
    if (e is Map && e['k'] == 'roll' && e['from'] is num && widget.live.phase == 'move') {
      final pid = e['pid'] as String;
      _hold[pid] = (e['from'] as num).toInt();
      Future<void>.delayed(Duration(milliseconds: widget.live.i('diceMs', 1000)), () {
        if (mounted && _hold.remove(pid) != null) setState(() {});
      });
    } else {
      _hold.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final live = widget.live;
    final board = OieBoard.instance;
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map];
    final current = live.s('current');
    // Pions : plusieurs sur la même case = décalés
    final count = <int, int>{};
    final pawns = <Widget>[];
    for (final p in players) {
      final pos = (_hold[p['pid']] ?? (p['pos'] as num).toInt()).clamp(0, 63);
      final k = count[pos] = (count[pos] ?? 0) + 1;
      final pv = room.player(p['pid'] as String);
      if (pv == null) continue;
      final now = p['pid'] == current;
      final s = now ? 64.0 : 52.0;
      final c = board.centers[pos];
      pawns.add(AnimatedPositioned(
        key: ValueKey(p['pid']),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
        left: c.dx + 2 + (k - 1) * 38,
        top: c.dy - s - 10,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (now) BoxShadow(color: Pb.yellow.withValues(alpha: .9), blurRadius: 18, spreadRadius: 3),
                const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6)),
              ],
            ),
            child: PbAvatar(size: s, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
          ),
          CustomPaint(size: const Size(16, 10), painter: _PinTip(Pb.playerColor(pv.color))),
        ]),
      ));
    }
    return SizedBox.fromSize(
      size: OieBoard.size,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF17646A), Color(0xFF0F4553)]),
          border: Border.all(color: const Color(0xFF2C8C84), width: 2),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 60, offset: Offset(0, 30))],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _RoadPainter()))),
          // Le centre de la spirale
          Positioned(
            left: 300,
            top: 300,
            width: 720,
            height: 240,
            child: Center(child: Text('Jeu de l’oie', style: Pb.t(64, weight: 700, color: Pb.yellow))),
          ),
          Positioned(
            left: board.centers[0].dx - 40,
            top: board.centers[0].dy + 30,
            child: Text('DÉPART', style: Pb.t(18, weight: 700, color: const Color(0xFFA9D6CF)).copyWith(letterSpacing: 2)),
          ),
          for (var n = 1; n <= 63; n++) _cell(n, board.centers[n]),
          ...pawns,
        ]),
      ),
    );
  }

  Widget _cell(int n, Offset c) {
    final s = oieSpecial(n);
    final size = n == 63 ? 92.0 : 68.0;
    return Positioned(
      left: c.dx - size / 2,
      top: c.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: s?.bg ?? Pb.text,
          border: s == null ? Border.all(color: const Color(0xFFC7B98F), width: 3) : null,
          boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 4))],
        ),
        child: Text('$n', style: Pb.t(n == 63 ? 36 : 26, weight: 700, color: s?.fg ?? const Color(0xFF17102B))),
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

/// Un dé (points dessinés)
/// Un dé. Avec [rollKey] : à chaque nouvelle valeur de la clé, il est lancé (il tourne, saute
/// et change de face pendant [rollMs]) avant de s'arrêter sur [value].
class OieDie extends StatefulWidget {
  const OieDie({super.key, required this.value, this.size = 100, this.angle = 0, this.rollKey, this.rollMs = 1000});
  final int? value; // null = « ? »
  final double size;
  final double angle;
  final Object? rollKey;
  final int rollMs;

  @override
  State<OieDie> createState() => _OieDieState();
}

class _OieDieState extends State<OieDie> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.rollMs));
  final _rand = math.Random();
  Object? _rolled;
  int _face = 1;
  int _lastTick = -1;

  @override
  void initState() {
    super.initState();
    _c.addListener(_tick);
    _maybeRoll();
  }

  @override
  void didUpdateWidget(covariant OieDie old) {
    super.didUpdateWidget(old);
    _maybeRoll();
  }

  void _maybeRoll() {
    final k = widget.rollKey;
    if (k == null || k == _rolled || widget.value == null) return;
    _rolled = k;
    _c.duration = Duration(milliseconds: widget.rollMs);
    _c.forward(from: 0);
  }

  // Nouvelle face au hasard, de moins en moins souvent (le dé ralentit)
  void _tick() {
    final t = _c.value;
    final tick = (math.pow(t, .6) * 11).floor();
    if (tick != _lastTick && t < .82) {
      _lastTick = tick;
      setState(() {
        var f = 1 + _rand.nextInt(6);
        if (f == _face) f = f % 6 + 1;
        _face = f;
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final rolling = _c.isAnimating && _c.value < .82;
        final t = Curves.easeOutCubic.transform(_c.value);
        // Tours sur lui-même qui ralentissent, deux rebonds de plus en plus petits
        final spin = _c.isAnimating ? (1 - t) * math.pi * 5 : 0.0;
        final hop = _c.isAnimating ? (math.sin(_c.value * math.pi * 2).abs() * (1 - _c.value)) * widget.size * .55 : 0.0;
        final squash = _c.isAnimating ? 1 + .12 * math.sin(_c.value * math.pi * 4) * (1 - _c.value) : 1.0;
        return Transform.translate(
          offset: Offset(0, -hop),
          child: Transform.scale(
            scale: squash,
            child: OieDieFace(value: rolling ? _face : widget.value, size: widget.size, angle: widget.angle + spin),
          ),
        );
      },
    );
  }
}

/// La face d'un dé, sans animation
class OieDieFace extends StatelessWidget {
  const OieDieFace({super.key, required this.value, this.size = 100, this.angle = 0});
  final int? value; // null = « ? »
  final double size;
  final double angle;

  static const _pips = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final on = _pips[value] ?? const <int>[];
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .16),
        decoration: BoxDecoration(
          color: Pb.text,
          borderRadius: BorderRadius.circular(size * .2),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: value == null
            ? Center(child: Text('?', style: Pb.t(size * .5, weight: 700, color: const Color(0xFF17102B))))
            : GridView.count(
                crossAxisCount: 3,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < 9; i++)
                    Center(
                      child: on.contains(i)
                          ? Container(width: size * .15, height: size * .15, decoration: const BoxDecoration(color: Color(0xFF17102B), shape: BoxShape.circle))
                          : null,
                    ),
                ],
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

String _status(Map p) {
  final h = (p['hotel'] as num?)?.toInt() ?? 0;
  if (h > 0) return 'à l’hôtel';
  return switch (p['stuck']) { 'puits' => 'au fond du puits', 'prison' => 'en prison', _ => '' };
}

// =================================================================== TV

class OieTv extends StatelessWidget {
  const OieTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🎲',
        title: 'Jeu de l’oie',
        sub: 'Le premier sur la case 63 gagne… en tombant pile !',
        rules: const [
          'Chacun lance les deux dés sur son téléphone.',
          'Oie : on rejoue son lancer. Pont, labyrinthe, mort : on saute ou on recule.',
          'Hôtel : 2 tours de repos. Puits et prison : on attend qu’un autre vienne prendre sa place.',
          'Case Défi : une question ! Bonne réponse +3 cases, sinon -3.',
        ],
        live: live,
      );
    }
    return DecoratedBox(
      decoration: oiePond,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            const SizedBox(height: 60),
            OieBoardView(room: room, live: live),
          ]),
          const SizedBox(width: 40),
          Expanded(child: _side()),
        ]),
      ),
    );
  }

  Widget _side() {
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final dice = [for (final d in (live['dice'] as List? ?? const [])) (d as num).toInt()];
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map]
      ..sort((a, b) => (b['pos'] as num).compareTo(a['pos'] as num));
    final defi = live['defi'] as Map?;
    final ph = live.phase;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 92,
        child: Row(children: [
          if (cur != null) ...[
            PbAvatar(size: 76, emoji: cur.emoji, color: cur.color, photoPath: cur.photo),
            const SizedBox(width: 16),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ph == 'defi' ? 'Défi pour' : 'Au tour de', style: Pb.t(22, color: const Color(0xFFA9D6CF))),
                Text(cur.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(42, weight: 700, color: Pb.yellow)),
              ]),
            ),
          ] else
            const Spacer(),
          OieDie(value: dice.isNotEmpty ? dice[0] : null, size: 84, angle: -.08, rollKey: ph == 'move' ? live.i('seq') : null, rollMs: live.i('diceMs', 1000)),
          const SizedBox(width: 14),
          OieDie(value: dice.length > 1 ? dice[1] : null, size: 84, angle: .1, rollKey: ph == 'move' ? live.i('seq') : null, rollMs: live.i('diceMs', 1000)),
        ]),
      ),
      const SizedBox(height: 18),
      if (ph == 'turn') ...[
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 10),
        const SizedBox(height: 18),
      ],
      if (defi != null) ...[
        Text(defi['question'] as String? ?? '', style: Pb.t(34, weight: 700, height: 1.15)),
        const SizedBox(height: 16),
        TvChoices(
          room: room,
          choices: [for (final c in (defi['choices'] as List? ?? const [])) '$c'],
          cols: 1,
          height: 74,
          correct: (defi['correct'] as num?)?.toInt(),
          picks: defi['answer'] is num ? {defi['pid'] as String: (defi['answer'] as num).toInt()} : const {},
        ),
        if (ph == 'defi') ...[const SizedBox(height: 14), TimeBar(endsIn: live.endsIn, duration: live.duration, height: 10)],
        if (ph == 'defi_reveal') ...[const SizedBox(height: 14), for (final m in _msgs(live)) Text(m, style: Pb.t(30, weight: 700))],
      ] else
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey(live.i('seq')),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _msgs(live).isEmpty ? Colors.transparent : Pb.yellow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, m) in _msgs(live).indexed)
                Text(m, style: Pb.t(i == 0 ? 30 : 26, weight: i == 0 ? 700 : 600, color: const Color(0xFF17102B))),
            ]),
          ),
        ),
      const SizedBox(height: 18),
      // Les joueurs, du plus avancé au moins avancé
      Expanded(
        child: ClipRect(
          // Pendant un défi, la question prend de la place : la liste est coupée en bas sans erreur de débordement
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(children: [
            for (final p in players)
              if (room.player(p['pid'] as String) case final pv?)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: p['pid'] == current ? Colors.white.withValues(alpha: .16) : Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    PbAvatar(size: players.length > 8 ? 34 : 42, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
                    const SizedBox(width: 14),
                    Expanded(child: Text(pv.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(26, weight: 600))),
                    Text(_status(p), style: Pb.t(20, color: const Color(0xFFA9D6CF))),
                    SizedBox(width: 64, child: Text('${p['pos']}', textAlign: TextAlign.right, style: Pb.t(30, weight: 700, color: Pb.yellow))),
                  ]),
                ),
          ]),
          ),
        ),
      ),
      // Légende des cases spéciales
      Wrap(spacing: 18, runSpacing: 6, children: [
        for (final n in const [5, 6, 10, 19, 31, 42, 52, 58, 63])
          if (oieSpecial(n) case final s?)
            SizedBox(width: 470, child: Row(children: [
              Container(width: 20, height: 20, decoration: BoxDecoration(color: s.bg, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text.rich(TextSpan(children: [
                TextSpan(text: '${s.label} ', style: Pb.t(18, weight: 700)),
                TextSpan(text: s.rule, style: Pb.t(18, color: const Color(0xFFA9D6CF))),
              ])),
            ])),
      ]),
    ]);
  }
}

// =================================================================== téléphone

class OiePlay extends StatelessWidget {
  const OiePlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
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
      'intro' => const PhoneCenter(emoji: '🎲', title: 'Jeu de l’oie', sub: 'Lance les dés à ton tour. Le premier pile sur la 63 gagne !'),
      'podium' => phoneRank(you),
      _ => you?['inGame'] == true ? _game() : const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !'),
    };
    return DecoratedBox(
      decoration: oiePond,
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
    final pos = you.yi('pos') ?? 0;
    final me = [for (final p in (live['players'] as List? ?? const [])) p as Map].where((p) => p['pid'] == _myPid()).firstOrNull;
    final status = me == null ? '' : _status(me);
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final dice = [for (final d in (live['dice'] as List? ?? const [])) (d as num).toInt()];
    final ph = live.phase;

    Widget header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('Case $pos', style: Pb.t(24, weight: 700, color: Pb.yellow)),
        const Spacer(),
        if (status.isNotEmpty) Text(status, style: Pb.t(16, weight: 600, color: const Color(0xFFA9D6CF))),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(value: pos / 63, minHeight: 10, color: Pb.pink, backgroundColor: Colors.black26),
      ),
    ]);

    Widget middle;
    if (ph == 'defi' && you.yb('myDefi')) {
      final defi = live['defi'] as Map;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Défi ! Bonne réponse +3, sinon -3', style: Pb.t(16, weight: 700, color: Pb.green)),
          const SizedBox(height: 6),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 6),
          const SizedBox(height: 10),
          Text(defi['question'] as String? ?? '', textAlign: TextAlign.center, style: Pb.t(22, weight: 700, height: 1.2)),
          const SizedBox(height: 12),
          Expanded(
            child: PhoneChoices(
              choices: [for (final c in (defi['choices'] as List? ?? const [])) '$c'],
              picked: you.yi('answer'),
              onPick: (i) => _g({'t': 'oie_answer', 'choice': i}),
            ),
          ),
        ]),
      );
    }
    if (you.yb('myTurn')) {
      middle = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('À toi de jouer !', style: Pb.t(30, weight: 700, color: Pb.yellow)),
        const SizedBox(height: 26),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OieDie(value: null, size: 110, angle: -.12),
          SizedBox(width: 22),
          OieDie(value: null, size: 110, angle: .14),
        ]),
        const SizedBox(height: 18),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 6),
      ]);
    } else {
      final msgs = _msgs(live);
      middle = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (cur != null) ...[
          PbAvatar(size: 70, emoji: cur.emoji, color: cur.color, photoPath: cur.photo),
          const SizedBox(height: 8),
          Text(ph == 'defi' ? '${cur.name} répond au défi…' : (current == _myPid() ? 'C’est toi !' : 'À ${cur.name} de jouer'),
              textAlign: TextAlign.center, style: Pb.t(22, weight: 700)),
        ],
        if (dice.length == 2 && ph != 'turn') ...[
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OieDie(value: dice[0], size: 72, angle: -.08, rollKey: ph == 'move' ? live.i('seq') : null, rollMs: live.i('diceMs', 1000)),
            const SizedBox(width: 14),
            OieDie(value: dice[1], size: 72, angle: .1, rollKey: ph == 'move' ? live.i('seq') : null, rollMs: live.i('diceMs', 1000)),
          ]),
        ],
        const SizedBox(height: 18),
        for (final m in msgs) Text(m, textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: Pb.text)),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Expanded(child: middle),
        if (you.yb('myTurn'))
          SizedBox(
            height: 72,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                _g({'t': 'oie_roll'});
              },
              child: Text('Lancer les dés', style: Pb.t(26, weight: 700)),
            ),
          ),
      ]),
    );
  }

  String? _myPid() => you?['pid'] as String?;
}
