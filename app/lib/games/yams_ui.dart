import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

// =================================================================== règles (comme server/src/games/yams.js)

const ymsCats = ['1', '2', '3', '4', '5', '6', 'brelan', 'carre', 'full', 'petite', 'grande', 'yams', 'chance'];
const ymsLabels = {
  '1': 'As', '2': 'Deux', '3': 'Trois', '4': 'Quatre', '5': 'Cinq', '6': 'Six',
  'brelan': 'Brelan', 'carre': 'Carré', 'full': 'Full', 'petite': 'Petite suite', 'grande': 'Grande suite', 'yams': 'Yams', 'chance': 'Chance',
};
const _hints = {'brelan': '3 pareils', 'carre': '4 pareils', 'full': '25', 'petite': '30', 'grande': '40', 'yams': '50', 'chance': 'total'};

int ymsScore(String k, List<int> dice) {
  final c = List.filled(7, 0);
  for (final v in dice) {
    if (v >= 1 && v <= 6) c[v]++;
  }
  final sum = dice.fold(0, (a, b) => a + b);
  final max = c.reduce(math.max);
  bool has(List<int> s) => s.every((v) => c[v] > 0);
  return switch (k) {
    'brelan' => max >= 3 ? sum : 0,
    'carre' => max >= 4 ? sum : 0,
    'full' => c.contains(3) && c.contains(2) ? 25 : 0,
    'petite' => has([1, 2, 3, 4]) || has([2, 3, 4, 5]) || has([3, 4, 5, 6]) ? 30 : 0,
    'grande' => has([1, 2, 3, 4, 5]) || has([2, 3, 4, 5, 6]) ? 40 : 0,
    'yams' => max == 5 ? 50 : 0,
    'chance' => sum,
    _ => c[int.parse(k)] * int.parse(k),
  };
}

// =================================================================== style « piste en bois »

const _ink = Color(0xFF3A2A1C);
const _cream = Color(0xFFFFF6E6);
const _soft = Color(0xFFE5CFA8);
const _panel = Color(0xFF4A3726);
const _sheet = Color(0xFFF6E7C8);
const _line = Color(0xFFD8BF93);
const _head = Color(0xFFEBD5A8);
const _hi = Color(0xFFFFD49A);
const _red = Color(0xFFD9472B);
const _green = Color(0xFF2E9E4F);

const ymsBg = BoxDecoration(
  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A2A1C), Color(0xFF2B2018)]),
);

/// La piste : planches de bois et rebord
class _WoodPainter extends CustomPainter {
  const _WoodPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(30));
    canvas.save();
    canvas.clipRRect(r);
    const planks = [Color(0xFF9A6A3E), Color(0xFF8E6037), Color(0xFFA4734A), Color(0xFF936539)];
    var x = 0.0, i = 0;
    while (x < size.width) {
      final w = 34.0 + (i * 37 % 23);
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), Paint()..color = planks[i % planks.length]);
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), Paint()..color = const Color(0x22000000));
      // veines
      final vein = Paint()
        ..color = const Color(0x18000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var k = 0; k < 3; k++) {
        final p = Path()..moveTo(x + 8 + k * 9, 0);
        for (var y = 0.0; y <= size.height; y += 40) {
          p.lineTo(x + 8 + k * 9 + math.sin((y + i * 50 + k * 30) / 60) * 3, y);
        }
        canvas.drawPath(p, vein);
      }
      x += w;
      i++;
    }
    // ombre intérieure
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x00000000), Color(0x66000000)], stops: [.55, 1]).createShader(Offset.zero & size),
    );
    canvas.restore();
    canvas.drawRRect(r.deflate(7), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = const Color(0xFF5A3B20));
    canvas.drawRRect(r.deflate(15), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF6E4828));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Un dé crème aux points rouges ; [held] = gardé (anneau vert)
class YmsDie extends StatelessWidget {
  const YmsDie({super.key, required this.value, this.size = 100, this.held = false, this.blank = false});
  final int value;
  final double size;
  final bool held;
  final bool blank;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _DiePainter(value, held, blank)));
}

class _DiePainter extends CustomPainter {
  const _DiePainter(this.v, this.held, this.blank);
  final int v;
  final bool held, blank;

  static const _pips = {
    1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * .22));
    if (blank) {
      canvas.drawRRect(r, Paint()..color = const Color(0x33FFF6E6));
      canvas.drawRRect(r.deflate(2), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x66FFF6E6));
      return;
    }
    if (held) canvas.drawRRect(r.inflate(s * .07), Paint()..color = _green);
    canvas.drawRRect(r.shift(Offset(0, s * .06)), Paint()..color = const Color(0x55000000));
    canvas.drawRRect(
      r,
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFCF4), Color(0xFFF1E3C8)]).createShader(Offset.zero & size),
    );
    final pip = Paint()..color = _red;
    for (final i in _pips[v] ?? const <int>[]) {
      final cx = s * (.23 + .27 * (i % 3)), cy = s * (.23 + .27 * (i ~/ 3));
      canvas.drawCircle(Offset(cx, cy), s * .09, pip);
    }
  }

  @override
  bool shouldRepaint(covariant _DiePainter o) => o.v != v || o.held != held || o.blank != blank;
}

List<int> _dice(Map<String, dynamic> live) => [for (final d in (live['dice'] as List? ?? const [0, 0, 0, 0, 0])) (d as num).toInt()];
List<bool> _held(Map<String, dynamic> live) => [for (final h in (live['held'] as List? ?? const [])) h == true];
List<int> _rolled(Map<String, dynamic> live) => [for (final d in (live['rolled'] as List? ?? const [])) (d as num).toInt()];
Map _sheetOf(Map<String, dynamic> live, String? pid) =>
    ((live['players'] as List? ?? const []).cast<Map>().where((p) => p['pid'] == pid).firstOrNull?['sheet'] as Map?) ?? const {};

// =================================================================== la piste animée (TV)

class _Pose {
  const _Pose(this.x, this.y, this.r);
  final double x, y, r; // coin haut gauche, angle en radians
}

/// La piste de dés : les dés relancés entrent par le bas, roulent, rebondissent et se posent
/// chacun dans une case différente d'une grille 4 × 2 (jamais l'un sur l'autre) ;
/// les dés gardés vont dans la zone « Dés gardés » en haut.
class YmsTray extends StatefulWidget {
  const YmsTray({super.key, required this.live});
  final Map<String, dynamic> live;

  @override
  State<YmsTray> createState() => _YmsTrayState();
}

class _YmsTrayState extends State<YmsTray> with SingleTickerProviderStateMixin {
  static const ds = 108.0;
  static const keptTop = 30.0, keptH = 150.0;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  final _rnd = math.Random();
  Size _size = const Size(720, 600);
  List<_Pose> _rest = [];
  // Animation en cours : départ, sommet, arrivée, tours, retard et durée (en fraction de l'animation)
  final _from = <int, Offset>{}, _mid = <int, Offset>{}, _turns = <int, double>{}, _start = <int, double>{}, _len = <int, double>{};
  Set<int> _rolling = {};
  int _rollSeq = 0;
  String _turnKey = '';

  @override
  void initState() {
    super.initState();
    _rollSeq = widget.live.i('rollSeq');
    _turnKey = _keyOf(widget.live);
    _rest = _home();
    if (_dice(widget.live).any((v) => v > 0)) {
      final t = _scatter([0, 1, 2, 3, 4]);
      for (final e in t.entries) {
        _rest[e.key] = e.value;
      }
    }
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _rolling = {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _keyOf(Map<String, dynamic> l) => '${l['round']}-${l['current']}';

  List<_Pose> _home() {
    final total = 5 * ds + 4 * 26;
    return [for (var i = 0; i < 5; i++) _Pose((_size.width - total) / 2 + i * (ds + 26), _size.height / 2 + 30, 0)];
  }

  _Pose _kept(int k) {
    final total = 5 * ds + 4 * 22;
    return _Pose((_size.width - total) / 2 + k * (ds + 22), keptTop + (keptH - ds) / 2, 0);
  }

  Map<int, _Pose> _scatter(List<int> idx) {
    final x0 = 34.0, x1 = _size.width - 34, y0 = keptTop + keptH + 20, y1 = _size.height - 70;
    final cw = (x1 - x0) / 4, ch = (y1 - y0) / 2, box = ds * 1.3;
    final cells = [for (var i = 0; i < 8; i++) i]..shuffle(_rnd);
    final out = <int, _Pose>{};
    for (final (n, i) in idx.indexed) {
      final c = cells[n], col = c % 4, row = c ~/ 4;
      final jx = math.max(0.0, cw - box), jy = math.max(0.0, ch - box);
      out[i] = _Pose(
        x0 + col * cw + (cw - ds) / 2 + (_rnd.nextDouble() - .5) * jx,
        y0 + row * ch + (ch - ds) / 2 + (_rnd.nextDouble() - .5) * jy,
        (_rnd.nextDouble() * 40 - 20) * math.pi / 180,
      );
    }
    return out;
  }

  @override
  void didUpdateWidget(covariant YmsTray old) {
    super.didUpdateWidget(old);
    final live = widget.live;
    final key = _keyOf(live);
    if (key != _turnKey) {
      _turnKey = key;
      _c.stop();
      _rolling = {};
      _rest = _home();
    }
    final seq = live.i('rollSeq');
    if (seq != _rollSeq) {
      _rollSeq = seq;
      final idx = _rolled(live);
      if (idx.isEmpty) return;
      final t = _scatter(idx);
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      for (final i in idx) {
        final p = t[i]!;
        _rest[i] = p;
        _from[i] = Offset(_size.width * (.15 + _rnd.nextDouble() * .7), _size.height + 60);
        _mid[i] = Offset((_from[i]!.dx + p.x) / 2 + _rnd.nextDouble() * 80 - 40, p.y - 60 - _rnd.nextDouble() * 50);
        _turns[i] = (_rnd.nextBool() ? 1 : -1) * (3 + _rnd.nextDouble() * 2) * math.pi;
        final n = idx.indexOf(i);
        _start[i] = n * .05;
        _len[i] = .62 + _rnd.nextDouble() * .12;
      }
      if (reduce) return;
      _rolling = idx.toSet();
      _c.forward(from: 0);
    }
  }

  // Position pendant le lancer (t = 0…1 pour ce dé) : monte, retombe, rebondit, se pose
  _Pose _flight(int i, double t) {
    final p = _rest[i], a = _from[i]!, m = _mid[i]!, b = Offset(p.x, p.y);
    double lerp(double x, double y, double k) => x + (y - x) * k;
    if (t < .38) {
      final k = Curves.easeOutCubic.transform(t / .38);
      return _Pose(lerp(a.dx, m.dx, k), lerp(a.dy, m.dy, k), p.r - _turns[i]! * (1 - .7 * k));
    }
    if (t < .62) {
      final k = Curves.easeInCubic.transform((t - .38) / .24);
      return _Pose(lerp(m.dx, b.dx, k), lerp(m.dy, b.dy, k), p.r - _turns[i]! * .3 * (1 - k) - .2 * k);
    }
    if (t < .8) {
      final k = math.sin((t - .62) / .18 * math.pi);
      return _Pose(b.dx + 4 * k, b.dy - 14 * k, p.r - .2 + .3 * ((t - .62) / .18));
    }
    final k = Curves.easeOut.transform((t - .8) / .2);
    return _Pose(b.dx, b.dy, p.r + .1 * (1 - k));
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final dice = _dice(live);
    final held = _held(live);
    final left = live.i('left', 3);
    return LayoutBuilder(builder: (context, cons) {
      final sz = Size(cons.maxWidth, cons.maxHeight);
      if (sz != _size) {
        _size = sz;
        if (dice.every((v) => v == 0)) _rest = _home();
      }
      return Stack(clipBehavior: Clip.hardEdge, children: [
        const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _WoodPainter()))),
        Positioned(
          left: 30,
          right: 30,
          top: keptTop - 6,
          height: keptH + 12,
          child: Container(
            decoration: BoxDecoration(color: const Color(0x30000000), borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
            alignment: Alignment.topLeft,
            child: Text('DÉS GARDÉS', style: Pb.t(16, weight: 700, color: const Color(0xAAFFFFFF)).copyWith(letterSpacing: 2)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 22,
          child: Text(
            live.phase != 'turn' || _rolling.isNotEmpty
                ? ''
                : left == 3
                    ? 'Les dés attendent…'
                    : left > 0
                        ? 'Encore $left lancer${left > 1 ? 's' : ''}'
                        : 'Plus de lancer : choisir une case',
            textAlign: TextAlign.center,
            style: Pb.t(24, weight: 600, color: _cream).copyWith(shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            var k = 0;
            final kept = <int, _Pose>{};
            for (var i = 0; i < 5; i++) {
              if (held.length > i && held[i] && dice[i] > 0 && !_rolling.contains(i)) kept[i] = _kept(k++);
            }
            final bucket = (_c.value * 1500 / 75).floor();
            final children = <Widget>[];
            for (var i = 0; i < 5; i++) {
              final blank = dice[i] == 0;
              if (_rolling.contains(i)) {
                final t = ((_c.value - _start[i]!) / _len[i]!.clamp(.01, 1)).clamp(0.0, 1.0);
                final p = _flight(i, t);
                // La face défile tant que le dé n'a pas touché la piste
                final face = t < .6 ? math.Random(bucket * 7 + i).nextInt(6) + 1 : dice[i];
                final sc = t < .38 ? .8 + .4 * (t / .38) : (t < .62 ? 1.2 - .3 * ((t - .38) / .24) : (t < .8 ? .9 + .12 * ((t - .62) / .18) : 1.0));
                children.add(Positioned(
                  key: ValueKey('r$i'),
                  left: p.x,
                  top: p.y,
                  child: Transform.rotate(angle: p.r, child: Transform.scale(scale: sc, child: YmsDie(value: face, size: ds))),
                ));
              } else {
                final p = kept[i] ?? _rest[i];
                children.add(AnimatedPositioned(
                  key: ValueKey('d$i'),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  left: p.x,
                  top: p.y,
                  child: AnimatedRotation(
                    turns: p.r / (2 * math.pi),
                    duration: const Duration(milliseconds: 420),
                    child: YmsDie(value: dice[i], size: ds, held: kept.containsKey(i), blank: blank),
                  ),
                ));
              }
            }
            return Stack(children: children);
          },
        ),
      ]);
    });
  }
}

// =================================================================== TV

class YmsTv extends StatelessWidget {
  const YmsTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🎲',
        title: 'Yams',
        sub: '13 tours pour remplir sa feuille de marque',
        rules: const [
          'À ton tour, lance les 5 dés sur ton téléphone : 3 lancers maximum.',
          'Entre deux lancers, touche les dés que tu veux garder.',
          'Puis choisis une case : elle vaut 0 si ta combinaison n’y est pas.',
          'Bonus de 35 si le haut de la feuille fait 63 ou plus. Le plus gros total gagne !',
        ],
        live: live,
      );
    }
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final left = live.i('left', 3);
    return DecoratedBox(
      decoration: ymsBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 760,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('Yams', style: Pb.t(54, weight: 700, color: _cream)),
                const Spacer(),
                Text('Tour ${live.i('round', 1)} / ${live.i('rounds', 13)}', style: Pb.t(28, weight: 600, color: _soft)),
              ]),
              const SizedBox(height: 14),
              Container(
                height: 118,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(26)),
                child: Row(children: [
                  if (cur != null) ...[
                    PbAvatar(size: 82, emoji: cur.emoji, color: cur.color, photoPath: cur.photo),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Au tour de', style: Pb.t(22, color: _soft)),
                        Text(cur.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(46, weight: 700, color: Pb.yellow)),
                      ]),
                    ),
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _red.withValues(alpha: i < left ? 1 : .25)),
                      ),
                  ] else
                    const Spacer(),
                ]),
              ),
              if (ph == 'turn') ...[
                const SizedBox(height: 10),
                TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
              ] else
                const SizedBox(height: 18),
              const SizedBox(height: 12),
              Expanded(child: YmsTray(live: live)),
              const SizedBox(height: 18),
              _event(),
            ]),
          ),
          const SizedBox(width: 40),
          Expanded(child: YmsSheet(room: room, live: live)),
        ]),
      ),
    );
  }

  Widget _event() {
    final e = live['event'];
    String text;
    var big = false;
    if (live.phase == 'scored' && e is Map) {
      final who = room.player(e['pid'] as String? ?? '')?.name ?? '?';
      final k = e['k'] as String? ?? '';
      final v = (e['v'] as num?)?.toInt() ?? 0;
      final label = ymsLabels[k] ?? k;
      big = k == 'yams' && v > 0;
      text = big
          ? '🎉 YAMS pour $who ! +50'
          : v > 0
              ? '${e['auto'] == true ? '⏰ ' : ''}$who inscrit $v en $label'
              : '${e['auto'] == true ? '⏰ ' : ''}$who raye $label';
    } else {
      text = '3 lancers, puis une case à remplir';
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(text),
        height: 96,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(color: live.phase == 'scored' ? (big ? Pb.yellow : _cream) : _panel, borderRadius: BorderRadius.circular(24)),
        child: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Pb.t(big ? 40 : 32, weight: 700, color: live.phase == 'scored' ? _ink : _soft)),
      ),
    );
  }
}

/// La feuille de marque de tous les joueurs (TV)
class YmsSheet extends StatelessWidget {
  const YmsSheet({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final players = [for (final p in (live['players'] as List? ?? const [])) p as Map];
    final current = live.s('current');
    final dice = _dice(live);
    final showPots = live.phase == 'turn' && live.i('left', 3) < 3 && dice.every((v) => v > 0);
    final n = math.max(1, players.length);
    final val = n <= 4 ? 34.0 : (n <= 8 ? 28.0 : 22.0);
    final av = n <= 6 ? 44.0 : (n <= 10 ? 34.0 : 28.0);

    Widget cell(Map p, Widget child, {bool sub = false}) {
      final now = p['pid'] == current;
      return Expanded(
        child: Container(
          alignment: Alignment.center,
          color: now ? _hi : (sub ? _head : null),
          child: child,
        ),
      );
    }

    Widget row(String label, {String? hint, required List<Widget> cells, bool sub = false, double flex = 1}) {
      return Expanded(
        flex: (flex * 10).round(),
        child: Container(
          decoration: BoxDecoration(
            color: sub ? _head : null,
            border: const Border(bottom: BorderSide(color: _line, width: 2)),
          ),
          child: Row(children: [
            SizedBox(
              width: 250,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: label, style: Pb.t(sub ? 26 : 25, weight: sub ? 700 : 600, color: _ink)),
                    if (hint != null) TextSpan(text: '  $hint', style: Pb.t(17, color: _ink.withValues(alpha: .55))),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ...cells,
          ]),
        ),
      );
    }

    final rows = <Widget>[
      // En-tête : les joueurs
      Expanded(
        flex: 18,
        child: Row(children: [
          SizedBox(width: 250, child: Padding(padding: const EdgeInsets.only(left: 14), child: Text('Feuille de marque', style: Pb.t(26, weight: 700, color: _ink)))),
          for (final p in players)
            cell(p, () {
              final pv = room.player(p['pid'] as String);
              return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (pv != null) PbAvatar(size: av, emoji: pv.emoji, color: pv.color, photoPath: pv.photo),
                const SizedBox(height: 2),
                Text(pv?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(n <= 6 ? 19 : 15, weight: 600, color: _ink)),
              ]);
            }()),
        ]),
      ),
    ];
    for (final k in ymsCats) {
      if (k == 'brelan') {
        rows.add(row('Bonus', hint: '63 → 35', sub: true, cells: [
          for (final p in players)
            cell(
              p,
              ((p['bonus'] as num?) ?? 0) > 0
                  ? Text('+35', style: Pb.t(val * .85, weight: 700, color: _green))
                  : Text('${p['up'] ?? 0}/63', style: Pb.t(val * .6, weight: 600, color: _ink.withValues(alpha: .55))),
              sub: true,
            ),
        ]));
      }
      rows.add(row(ymsLabels[k]!, hint: _hints[k], cells: [
        for (final p in players)
          cell(p, () {
            final v = (p['sheet'] as Map?)?[k];
            if (v is num) {
              return Text(v == 0 ? '✕' : '$v', style: Pb.t(val, weight: 600, color: _ink.withValues(alpha: v == 0 ? .4 : 1)));
            }
            if (showPots && p['pid'] == current) {
              final s = ymsScore(k, dice);
              return Text('$s', style: Pb.t(val * .8, weight: 600, color: _red.withValues(alpha: s == 0 ? .35 : .85)));
            }
            return const SizedBox.shrink();
          }()),
      ]));
    }
    rows.add(row('Total', sub: true, flex: 1.3, cells: [
      for (final p in players) cell(p, Text('${p['total'] ?? 0}', style: Pb.t(val * 1.1, weight: 700, color: _ink)), sub: true),
    ]));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _sheet,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 18))],
      ),
      child: Column(children: rows),
    );
  }
}

// =================================================================== téléphone

class YmsPlay extends StatefulWidget {
  const YmsPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<YmsPlay> createState() => _YmsPlayState();
}

class _YmsPlayState extends State<YmsPlay> with SingleTickerProviderStateMixin {
  // Les dés tremblent et changent de face pendant que la TV les fait rouler
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  int _rollSeq = 0;
  Set<int> _rolling = {};
  bool _sent = false;

  Map<String, dynamic> get live => widget.live;

  void _g(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': m});

  @override
  void initState() {
    super.initState();
    _rollSeq = live.i('rollSeq');
    _shake.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _rolling = {});
    });
  }

  @override
  void didUpdateWidget(covariant YmsPlay old) {
    super.didUpdateWidget(old);
    final seq = live.i('rollSeq');
    if (seq != _rollSeq) {
      _rollSeq = seq;
      _sent = false;
      _rolling = _rolled(live).toSet();
      if (_rolling.isNotEmpty && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
        _shake.forward(from: 0);
      } else {
        _rolling = {};
      }
    }
    if (live.phase != 'turn') _sent = false;
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🎲', title: 'Yams', sub: '3 lancers par tour, garde les bons dés, remplis ta feuille !'),
      'podium' => phoneRank(widget.you),
      _ => widget.you?['inGame'] == true ? _game() : const PhoneCenter(emoji: '👀', title: 'Partie en cours', sub: 'Regarde la TV : tu joueras à la prochaine !'),
    };
    return DecoratedBox(
      decoration: ymsBg,
      child: PhoneGameFrame(
        stepKey: '$ph-${live.i('seq')}-${live.s('current')}',
        isHost: widget.isHost,
        phase: ph,
        send: widget.send,
        skipLabel: 'Faire passer',
        child: body,
      ),
    );
  }

  Widget _game() {
    final room = widget.room;
    final myPid = widget.you?['pid'] as String?;
    final mine = widget.you.yb('myTurn');
    final current = live.s('current');
    final cur = current == null ? null : room.player(current);
    final dice = _dice(live);
    final held = _held(live);
    final left = live.i('left', 3);
    final rolling = _rolling.isNotEmpty;
    final rolled = left < 3 && dice.every((v) => v > 0);
    final sheet = _sheetOf(live, myPid);
    final me = (live['players'] as List? ?? const []).cast<Map>().where((p) => p['pid'] == myPid).firstOrNull;
    final canHold = mine && rolled && left > 0 && !rolling;

    final state = live.phase == 'scored'
        ? ''
        : mine
            ? (rolling ? 'Ça roule…' : (!rolled ? 'À toi de jouer !' : (left > 0 ? 'Touche les dés à garder, ou choisis une case' : 'Choisis une case')))
            : (cur == null ? '' : '${cur.name} joue…');

    final diceRow = AnimatedBuilder(
      animation: _shake,
      builder: (context, _) {
        final bucket = (_shake.value * 1000 / 75).floor();
        return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (var i = 0; i < 5; i++)
            () {
              final shaking = _rolling.contains(i) && _shake.value < .62;
              final face = shaking ? math.Random(bucket * 5 + i).nextInt(6) + 1 : dice[i];
              final dx = shaking ? math.sin(_shake.value * 90 + i) * 4 : 0.0;
              final dy = shaking ? math.cos(_shake.value * 70 + i * 2) * 5 : 0.0;
              final isHeld = held.length > i && held[i] && dice[i] > 0 && !_rolling.contains(i);
              return GestureDetector(
                onTap: canHold
                    ? () {
                        HapticFeedback.selectionClick();
                        _g({'t': 'yms_hold', 'i': i});
                      }
                    : null,
                child: AnimatedSlide(
                  offset: Offset(0, isHeld ? -.12 : 0),
                  duration: const Duration(milliseconds: 180),
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.rotate(
                      angle: shaking ? math.sin(_shake.value * 60 + i) * .3 : 0,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        YmsDie(value: face, size: 56, held: isHeld, blank: dice[i] == 0),
                        const SizedBox(height: 4),
                        Text(isHeld ? 'GARDÉ' : ' ', style: Pb.t(11, weight: 700, color: const Color(0xFF7BE09A)).copyWith(letterSpacing: 1)),
                      ]),
                    ),
                  ),
                ),
              );
            }(),
        ]);
      },
    );

    final pots = <String, int>{
      for (final k in ymsCats)
        if (sheet[k] == null && mine && rolled && !rolling) k: ymsScore(k, dice),
    };
    final best = pots.values.fold(0, math.max);

    Widget catRow(String k) {
      final done = sheet[k];
      final pot = pots[k];
      final enabled = pot != null && live.phase == 'turn';
      return Material(
        color: pot != null && pot == best && best > 0 ? _hi : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  _g({'t': 'yms_pick', 'k': k});
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: ymsLabels[k], style: Pb.t(17, weight: 600, color: _ink.withValues(alpha: done != null ? .45 : 1))),
                  if (done != null) TextSpan(text: '  ✓ inscrit', style: Pb.t(12, color: _ink.withValues(alpha: .45))),
                ])),
              ),
              Text(
                done is num ? (done == 0 ? '✕' : '$done') : (pot != null ? '$pot' : ''),
                style: Pb.t(20, weight: 700, color: done != null ? _ink.withValues(alpha: .45) : _red.withValues(alpha: pot == 0 ? .45 : 1)),
              ),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Tour ${live.i('round', 1)} / ${live.i('rounds', 13)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(18, weight: 600, color: _soft))),
          Text('Total ${me?['total'] ?? 0}', style: Pb.t(22, weight: 700, color: Pb.yellow)),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: Center(child: Text(state, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(18, weight: 700, color: _cream))),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8E6037),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF5A3B20), width: 5),
          ),
          child: diceRow,
        ),
        if (mine && live.phase == 'turn') ...[
          const SizedBox(height: 8),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 5),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: _cream,
              disabledBackgroundColor: _panel,
              disabledForegroundColor: _soft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: mine && left > 0 && !rolling && !_sent && live.phase == 'turn'
                ? () {
                    HapticFeedback.heavyImpact();
                    setState(() => _sent = true);
                    _g({'t': 'yms_roll'});
                  }
                : null,
            child: Text(
              !mine
                  ? 'Pas ton tour'
                  : rolling
                      ? 'Ça roule…'
                      : left == 3
                          ? '🎲 Lancer les dés'
                          : left > 0
                              ? '🎲 Relancer ($left restant${left > 1 ? 's' : ''})'
                              : 'Plus de lancer',
              style: Pb.t(22, weight: 700, color: mine && left > 0 && !rolling ? _cream : _soft),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: _sheet, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(4),
            child: ListView(padding: EdgeInsets.zero, children: [
              for (final k in ymsCats.take(6)) catRow(k),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: [
                  Text('Bonus (63 → 35)', style: Pb.t(14, weight: 700, color: _ink.withValues(alpha: .7))),
                  const Spacer(),
                  Text(((me?['bonus'] as num?) ?? 0) > 0 ? '+35' : '${me?['up'] ?? 0}/63', style: Pb.t(14, weight: 700, color: _ink.withValues(alpha: .7))),
                ]),
              ),
              const Divider(height: 1, color: _line, thickness: 2),
              for (final k in ymsCats.skip(6)) catRow(k),
            ]),
          ),
        ),
      ]),
    );
  }
}
