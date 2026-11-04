import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import '../widgets/fireworks.dart';
import 'common_ui.dart';

const _green = Color(0xFF3DAA3D);
const _red = Color(0xFFE53935);
const _ink = Color(0xFF111111);

/// Couleur d'une boule selon sa dizaine
Color lotoBallColor(int n) => const [
      Color(0xFFE53935), Color(0xFFFF8A3D), Color(0xFFF5C318), Color(0xFF3DAA3D), Color(0xFF2EC4B6),
      Color(0xFF2D7FE0), Color(0xFF7B5CFF), Color(0xFFC86BFF), Color(0xFFFF4FA3),
    ][(n >= 90 ? 8 : n ~/ 10)];

/// Une boule de loto
class LotoBall extends StatelessWidget {
  const LotoBall({super.key, required this.n, required this.size});
  final int n;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = lotoBallColor(n);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-.35, -.4), colors: [Color.lerp(c, Colors.white, .45)!, c, Color.lerp(c, Colors.black, .35)!], stops: const [0, .55, 1]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: size * .12, offset: Offset(0, size * .06))],
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * .58,
        height: size * .58,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Text('$n', style: Pb.t(size * .3, weight: 700, color: _ink, height: 1)),
      ),
    );
  }
}

/// La boule tirée sur la TV, version boulier : les boules tournent dans la sphère, puis une
/// boule sort par le bas, grossit et vient se poser au centre avec un rebond
class LotoDrumBall extends StatefulWidget {
  const LotoDrumBall({super.key, required this.n, required this.size});
  final int n;
  final double size;

  @override
  State<LotoDrumBall> createState() => _LotoDrumBallState();
}

class _LotoDrumBallState extends State<LotoDrumBall> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _rand = math.Random();
  List<_DrumBall> _balls = const [];

  @override
  void initState() {
    super.initState();
    _roll();
  }

  @override
  void didUpdateWidget(covariant LotoDrumBall old) {
    super.didUpdateWidget(old);
    if (old.n != widget.n) _roll();
  }

  void _roll() {
    _balls = [
      for (var i = 0; i < 18; i++)
        _DrumBall(1 + _rand.nextInt(90), _rand.nextDouble() * math.pi * 2, .6 + _rand.nextDouble() * .9, .35 + _rand.nextDouble() * .6),
    ];
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          // 0 → 0,62 : le boulier tourne ; 0,55 → 1 : la boule sort et vient au centre
          final drum = t < .62 ? 1.0 : (1 - (t - .62) / .2).clamp(0.0, 1.0);
          final out = ((t - .55) / .45).clamp(0.0, 1.0);
          return Stack(alignment: Alignment.center, children: [
            if (drum > 0)
              Opacity(
                opacity: drum,
                child: CustomPaint(size: Size(s, s), painter: _DrumPainter(_balls, t)),
              ),
            if (out > 0)
              Builder(builder: (_) {
                final move = Curves.easeOutCubic.transform((out / .6).clamp(0.0, 1.0));
                final scale = out < .6 ? .14 + .86 * move : 1 + .12 * math.sin((out - .6) / .4 * math.pi) * (1 - (out - .6) / .4);
                final dy = (1 - move) * s * .42;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(scale: scale, child: LotoBall(n: widget.n, size: s)),
                );
              }),
          ]);
        },
      ),
    );
  }
}

class _DrumBall {
  const _DrumBall(this.n, this.phase, this.speed, this.reach);
  final int n;
  final double phase, speed, reach;
}

class _DrumPainter extends CustomPainter {
  _DrumPainter(this.balls, this.t);
  final List<_DrumBall> balls;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * .44;
    // la sphère
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(center: const Alignment(-.3, -.4), colors: [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .03)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // le boulier tourne de plus en plus lentement
    final turn = (1 - math.pow(1 - t.clamp(0, .62) / .62, 2)) * math.pi * 7;
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: .28);
    for (var k = 0; k < 4; k++) {
      final w = (math.cos(turn + k * math.pi / 4)).abs() * r;
      canvas.drawOval(Rect.fromCenter(center: c, width: w * 2, height: r * 2), wire);
    }
    // les boules qui tournent dedans (tassées vers le bas, comme avec la gravité)
    final br = size.width * .06;
    for (final b in balls) {
      final a = b.phase + turn * b.speed;
      final p = c + Offset(math.cos(a) * r * b.reach * .78, math.sin(a) * r * b.reach * .55 + r * .22);
      final col = lotoBallColor(b.n);
      canvas.drawCircle(
        p,
        br,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-.4, -.4), colors: [Color.lerp(col, Colors.white, .5)!, col, Color.lerp(col, Colors.black, .35)!], stops: const [0, .5, 1])
              .createShader(Rect.fromCircle(center: p, radius: br)),
      );
      canvas.drawCircle(p, br * .45, Paint()..color = Colors.white);
    }
    // le cerclage et la sortie en bas
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0xFFFFD23F));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, r), width: br * 3.2, height: br * 1.4), Radius.circular(br * .5)),
      Paint()..color = const Color(0xFFFFD23F),
    );
  }

  @override
  bool shouldRepaint(covariant _DrumPainter old) => old.t != t || old.balls != balls;
}

/// Un carton : 3 lignes × 9 colonnes, cases vides de couleur (comme un carton papier),
/// cadre décoré et numéro de série (« N° 017/300 »)
class LotoCarton extends StatelessWidget {
  const LotoCarton({super.key, required this.grid, required this.marks, this.no, this.series = 300, this.onTap, this.width = 358, this.tint = _green});
  final List<List<int>> grid;
  final Set<int> marks;
  final int? no;
  final int series;
  final ValueChanged<int>? onTap;
  final double width;
  final Color tint;

  static const _outer = BorderRadius.only(topLeft: Radius.circular(22), bottomRight: Radius.circular(22), topRight: Radius.circular(8), bottomLeft: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final inner = width - 16;
    final cw = (inner - 6) / 9;
    final ch = cw * 1.28;
    final k = width / 358; // échelle des petits textes
    return Container(
      width: width,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: _outer,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_red, Color.lerp(_red, Pb.yellow, .55)!, _red]),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 7))],
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(5, 4 * k, 5, 5),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF2),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(19), bottomRight: Radius.circular(19), topRight: Radius.circular(5), bottomLeft: Radius.circular(5)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // En-tête : nom du jeu et numéro de série dans un onglet rouge
          Row(children: [
            Icon(Icons.star_rounded, size: 13 * k, color: _red),
            SizedBox(width: 3 * k),
            Text('PartyBroc · Loto', style: Pb.t(11.5 * k, weight: 700, color: _red).copyWith(fontStyle: FontStyle.italic)),
            const Spacer(),
            if (no != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8 * k, vertical: 2 * k),
                decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(6 * k)),
                child: Text('N° ${no.toString().padLeft(3, '0')}/$series', style: Pb.t(11.5 * k, weight: 700, color: Colors.white)),
              ),
          ]),
          SizedBox(height: 3 * k),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: _red, borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(12), topRight: Radius.circular(2), bottomLeft: Radius.circular(2))),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(10), topRight: Radius.circular(1), bottomLeft: Radius.circular(1)),
              child: Column(children: [
                for (var r = 0; r < 3; r++)
                  Row(children: [
                    for (var c = 0; c < 9; c++) _cell(grid[r][c], cw, ch, r, c),
                  ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cell(int n, double w, double h, int r, int c) {
    final border = Border(
      right: c < 8 ? const BorderSide(color: _red, width: 1.2) : BorderSide.none,
      bottom: r < 2 ? const BorderSide(color: _red, width: 1.2) : BorderSide.none,
    );
    if (n == 0) return Container(width: w, height: h, decoration: BoxDecoration(color: tint, border: border));
    final marked = marks.contains(n);
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(n),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: Colors.white, border: border),
        child: Stack(alignment: Alignment.center, children: [
          FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text('$n', style: Pb.t(h * .56, weight: 700, color: _ink, height: 1)),
            ),
          ),
          // Le jeton posé sur le numéro
          AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: marked ? 1 : 0,
            child: Container(
              width: w * .86,
              height: w * .86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Pb.pink.withValues(alpha: .62),
                border: Border.all(color: Pb.pink, width: 2.5),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

String _prizeShout(String? id) => switch (id) { 'ligne' => 'UNE LIGNE !', 'deux' => 'DEUX LIGNES !', 'plein' => 'CARTON PLEIN !', _ => '' };

List<List<int>> _grid(Object? g) => [for (final r in g as List) [for (final n in r as List) (n as num).toInt()]];

// =================================================================== TV

class LotoTv extends StatelessWidget {
  const LotoTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final paper = live['paper'] == true;
    if (ph == 'podium') return paper ? _paperWinners() : TvPodium(room: room, live: live);
    if (ph == 'intro' && paper) {
      return TvIntro(
        emoji: '🎱',
        title: 'Loto',
        sub: 'Sortez vos cartons et vos jetons !',
        rules: const [
          'La TV tire les boules de 1 à 90 : marquez vos numéros sur vos cartons.',
          'On joue une ligne, puis deux lignes, puis le carton plein.',
          'Vous avez gagné ? Criez-le ! L’hôte arrête le tirage et on vérifie ensemble.',
        ],
        live: live,
      );
    }
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🎱',
        title: 'Loto',
        sub: 'Une ligne, deux lignes, carton plein !',
        rules: [
          'Choisis ${live.i('perPlayer') == 2 ? 'tes 2 cartons' : 'ton carton'} sur ton téléphone, puis la TV tire les boules de 1 à 90.',
          live['auto'] == true
              ? 'Marquage automatique : les numéros se cochent tout seuls.'
              : 'Touche tes numéros pour poser un jeton, puis annonce « Une ligne ! » au bon moment. Faux = 5 s de pénalité.',
          'Une ligne (300), deux lignes (500), carton plein (1000).',
        ],
        live: live,
      );
    }
    if (ph == 'choose') return _choose();
    final drawn = {for (final n in (live['drawn'] as List? ?? const [])) (n as num).toInt()};
    final last = (live['last'] as num?)?.toInt();
    final prize = live['prize'] as Map?;
    final winners = [for (final w in (live['winners'] as List? ?? const [])) w as Map];
    final near = [for (final n in (live['near'] as List? ?? const [])) n as Map];
    final ev = live['event'] as Map?;
    final win = ph == 'win' && ev?['k'] == 'win';

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(70, 44, 70, 40),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // La boule tirée
        SizedBox(
          width: 560,
          child: Column(children: [
            Text('Boule ${drawn.length} / 90', style: Pb.t(34, weight: 600, color: Pb.muted)),
            const SizedBox(height: 26),
            // La boule qui sort du boulier, puis la dernière boule tirée
            if (live['rolling'] is num)
              LotoDrumBall(n: (live['rolling'] as num).toInt(), size: 400)
            else if (last != null)
              LotoBall(n: last, size: 400)
            else
              const SizedBox(width: 400, height: 400),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: Text(live.s('nick') == null ? '' : '« ${live.s('nick')} »', style: Pb.t(42, weight: 600, color: Pb.yellow)),
            ),
            const SizedBox(height: 14),
            if (prize != null)
              TvChip(text: paper ? 'On joue : ${prize['title']}' : 'On joue : ${prize['title']} (${prize['points']} pts)', bg: Pb.pink, size: 38),
            const SizedBox(height: 22),
            // Dernières boules
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final n in (live['drawn'] as List? ?? const []).reversed.skip(1).take(5))
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: LotoBall(n: (n as num).toInt(), size: 82)),
            ]),
          ]),
        ),
        const SizedBox(width: 60),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Le tableau des 90 numéros
            for (var r = 0; r < 9; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  for (var c = 0; c < 10; c++) ...[
                    if (c > 0) const SizedBox(width: 8),
                    Expanded(child: _boardCell(r * 10 + c + 1, drawn.contains(r * 10 + c + 1), r * 10 + c + 1 == last)),
                  ],
                ]),
              ),
            const SizedBox(height: 14),
            if (ph == 'draw' && live['paused'] != true) TimeBar(endsIn: live.endsIn, duration: live.duration, height: 10),
            const SizedBox(height: 18),
            // Qui s'approche, et les gagnants
            Wrap(spacing: 18, runSpacing: 12, children: [
              for (final w in winners) ...[
                for (final pid in [for (final p in (w['pids'] as List)) p as String])
                  if (room.player(pid) case final p?)
                    _chip(p, '🏆 ${w['title']}', Pb.yellow),
                for (final name in [for (final n in (w['names'] as List? ?? const [])) n as String])
                  _nameChip(name, '🏆 ${w['title']}'),
              ],
              for (final n in near)
                if (room.player(n['pid'] as String) case final p?)
                  _chip(p, n['miss'] == 1 ? 'attend 1 numéro !' : 'en attend 2', n['miss'] == 1 ? Pb.red : Pb.muted),
              if (ev?['k'] == 'wrong')
                if (room.player(ev!['pid'] as String) case final p?) _chip(p, '😅 s’est trompé !', Pb.red),
            ]),
          ]),
        ),
      ]),
    );
    if (live['paused'] == true) {
      return Stack(children: [
        Opacity(opacity: .3, child: content),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
            decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(40), border: Border.all(color: Pb.yellow, width: 6)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.pause_circle_filled_rounded, size: 160, color: Pb.yellow),
              Text('Pause', style: Pb.t(110, weight: 700)),
              Text('L’hôte reprendra la partie', style: Pb.t(36, color: Pb.muted)),
            ]),
          ),
        ),
      ]);
    }
    // Cartons papier : quelqu'un a crié, on vérifie avec les numéros sortis
    if (ph == 'check') {
      final sorted = drawn.toList()..sort();
      return Stack(children: [
        Opacity(opacity: .2, child: content),
        Center(
          child: Container(
            width: 1600,
            padding: const EdgeInsets.fromLTRB(50, 36, 50, 40),
            decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(40), border: Border.all(color: Pb.yellow, width: 6)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('📢 ${prize == null ? '' : '« ${prize['title']} ! »'}  On vérifie…', style: Pb.t(70, weight: 700, color: Pb.yellow)),
              const SizedBox(height: 10),
              Text('Les ${sorted.length} numéros sortis :', style: Pb.t(34, color: Pb.muted)),
              const SizedBox(height: 24),
              Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 14, children: [
                for (final n in sorted)
                  Container(
                    width: sorted.length > 50 ? 84 : 104,
                    height: sorted.length > 50 ? 64 : 78,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: lotoBallColor(n), borderRadius: BorderRadius.circular(16), border: n == last ? Border.all(color: Colors.white, width: 4) : null),
                    child: Text('$n', style: Pb.t(sorted.length > 50 ? 34 : 42, weight: 700, color: Colors.white)),
                  ),
              ]),
            ]),
          ),
        ),
      ]);
    }
    if (!win) return content;
    final pids = [for (final p in (ev!['pids'] as List? ?? const [])) p as String];
    final names = [for (final n in (ev['names'] as List? ?? const [])) n as String];
    return Stack(children: [
      Opacity(opacity: .25, child: content),
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_prizeShout(ev['prize'] as String?), style: Pb.t(150, weight: 700, color: Pb.yellow)),
          const SizedBox(height: 24),
          Wrap(spacing: 40, children: [
            for (final pid in pids)
              if (room.player(pid) case final p?)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  PbAvatar(size: 190, emoji: p.emoji, color: p.color, photoPath: p.photo),
                  const SizedBox(height: 12),
                  Text(p.name, style: Pb.t(60, weight: 700)),
                ]),
            for (final n in names) Text(n, style: Pb.t(110, weight: 700)),
          ]),
        ]),
      ),
      const Positioned.fill(child: Fireworks()),
    ]);
  }

  // Cartons papier : la liste des gagnants à la fin
  Widget _paperWinners() {
    final winners = [for (final w in (live['winners'] as List? ?? const [])) w as Map];
    return Stack(children: [
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🏆 Les gagnants', style: Pb.t(96, weight: 700, color: Pb.yellow)),
          const SizedBox(height: 40),
          if (winners.isEmpty) Text('Personne cette fois !', style: Pb.t(54, color: Pb.muted)),
          for (final w in winners)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 520, child: Text('${w['title']}', textAlign: TextAlign.right, style: Pb.t(58, weight: 600, color: Pb.muted))),
                const SizedBox(width: 40),
                Text(
                  [for (final n in (w['names'] as List? ?? const [])) n as String].isEmpty ? '?' : [for (final n in (w['names'] as List)) n as String].join(', '),
                  style: Pb.t(72, weight: 700),
                ),
              ]),
            ),
        ]),
      ),
      const Positioned.fill(child: IgnorePointer(child: Fireworks())),
    ]);
  }

  Widget _nameChip(String name, String text) => Container(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
        decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$name ', style: Pb.t(28, weight: 700)),
          Text(text, style: Pb.t(28, weight: 600, color: Pb.yellow)),
        ]),
      );

  // Le choix des cartons : chacun coche les siens sur son téléphone, la TV montre qui est prêt
  Widget _choose() {
    final picked = {for (final p in (live['picked'] as List? ?? const [])) (p as Map)['pid'] as String: p};
    final need = live.i('perPlayer');
    final players = room.players.where((p) => picked.containsKey(p.pid)).toList();
    final ready = players.where((p) => picked[p.pid]?['ready'] == true).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 70, 80, 60),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(need == 2 ? 'Choisissez vos 2 cartons !' : 'Choisissez votre carton !', textAlign: TextAlign.center, style: Pb.t(76, weight: 700)),
        const SizedBox(height: 12),
        Text('Chacun a sa liste de 20 cartons sur son téléphone · $ready / ${players.length} prêts',
            textAlign: TextAlign.center, style: Pb.t(36, color: Pb.muted)),
        const SizedBox(height: 28),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 12),
        const Spacer(),
        Wrap(alignment: WrapAlignment.center, spacing: 40, runSpacing: 34, children: [
          for (final p in players)
            Builder(builder: (_) {
              final n = (picked[p.pid]?['n'] as num?)?.toInt() ?? 0;
              final ok = picked[p.pid]?['ready'] == true;
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(clipBehavior: Clip.none, children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: ok ? 1 : .55,
                    child: PbAvatar(size: 150, emoji: p.emoji, color: p.color, photoPath: p.photo),
                  ),
                  Positioned(
                    right: -10,
                    bottom: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(color: ok ? Pb.green : Pb.card, borderRadius: BorderRadius.circular(22)),
                      child: ok
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_rounded, color: Pb.bg, size: 30),
                              Text('Prêt', style: Pb.t(28, weight: 700, color: Pb.bg)),
                            ])
                          : Text('$n/$need', style: Pb.t(28, weight: 700, color: Pb.text)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(p.name, style: Pb.t(34, weight: 600)),
              ]);
            }),
        ]),
        const Spacer(),
      ]),
    );
  }

  Widget _boardCell(int n, bool on, bool last) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? lotoBallColor(n) : Pb.card.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
        border: last ? Border.all(color: Colors.white, width: 5) : null,
      ),
      child: Text('$n', style: Pb.t(32, weight: 700, color: on ? Colors.white : Pb.muted.withValues(alpha: .5))),
    );
  }

  Widget _chip(PlayerView p, String text, Color c) => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
        decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PbAvatar(size: 46, emoji: p.emoji, color: p.color, photoPath: p.photo),
          const SizedBox(width: 12),
          Text('${p.name} ', style: Pb.t(28, weight: 700)),
          Text(text, style: Pb.t(28, weight: 600, color: c)),
        ]),
      );
}

// =================================================================== téléphone

class LotoPlay extends StatefulWidget {
  const LotoPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final String? myPid;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<LotoPlay> createState() => _LotoPlayState();
}

class _LotoPlayState extends State<LotoPlay> {
  // Blocage après un faux « Quine ! » : compté sur le téléphone
  DateTime _lockedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didUpdateWidget(covariant LotoPlay old) {
    super.didUpdateWidget(old);
    final ms = widget.you.yi('lockedFor') ?? 0;
    if (ms > 0) _lockedUntil = DateTime.now().add(Duration(milliseconds: ms));
  }

  void _g(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': m});
  final _winner = TextEditingController();

  @override
  void dispose() {
    _winner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final ph = live.phase;
    final paper = live['paper'] == true;
    final Widget body = paper
        ? _paper()
        : switch (ph) {
      'intro' => PhoneCenter(
          emoji: '🎱',
          title: 'Loto',
          sub: live['auto'] == true
              ? 'Choisis ${live.i('perPlayer') == 2 ? 'tes 2 cartons' : 'ton carton'}, les numéros se cocheront tout seuls.'
              : 'Choisis ${live.i('perPlayer') == 2 ? 'tes 2 cartons' : 'ton carton'}, touche tes numéros quand ils sortent, puis annonce « Une ligne ! »',
        ),
      'choose' => _choose(),
      'podium' => phoneRank(widget.you),
      _ => _game(),
    };
    final paused = live['paused'] == true;
    return PhoneGameFrame(
        stepKey: ph == 'podium' || ph == 'intro' || ph == 'choose' ? ph : 'game',
        skipLabel: ph == 'choose' ? 'Lancer sans attendre' : 'Boule suivante',
        hostActions: ph == 'draw' || ph == 'win'
            ? [(label: paused ? 'Reprendre' : 'Pause', icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded, msg: const {'t': 'game_pause'})]
            : const [],
        isHost: widget.isHost, phase: ph, send: widget.send, child: body);
  }

  // Cartons papier : les joueurs suivent la TV ; l'hôte arrête le tirage pour vérifier un gagnant
  Widget _paper() {
    final live = widget.live;
    final ph = live.phase;
    final last = (live['last'] as num?)?.toInt();
    final prize = live['prize'] as Map?;
    if (ph == 'intro') {
      return const PhoneCenter(emoji: '🎱', title: 'Loto', sub: 'On joue avec de vrais cartons : sortez vos jetons, la TV tire les boules.');
    }
    if (ph == 'podium') {
      final winners = [for (final w in (live['winners'] as List? ?? const [])) w as Map];
      return PhoneCenter(
        emoji: '🏆',
        title: 'Les gagnants',
        sub: winners.isEmpty
            ? 'Personne cette fois !'
            : [for (final w in winners) '${w['title']} : ${[for (final n in (w['names'] as List? ?? const [])) n as String].join(', ')}'].join('\n'),
      );
    }
    final recent = [for (final n in (live['drawn'] as List? ?? const []).reversed.skip(1).take(5)) (n as num).toInt()];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (prize != null) Padding(padding: const EdgeInsets.only(right: 44), child: Text('On joue : ${prize['title']}', style: Pb.t(22, weight: 700, color: Pb.yellow))),
        Text('Boule ${(live['drawn'] as List? ?? const []).length} / 90 · cartons papier', style: Pb.t(15, color: Pb.muted)),
        const Spacer(),
        Center(child: last == null ? const SizedBox(height: 180) : LotoBall(n: last, size: 180)),
        if (live.s('nick') != null) ...[const SizedBox(height: 8), Text('« ${live.s('nick')} »', textAlign: TextAlign.center, style: Pb.t(20, weight: 600, color: Pb.yellow))],
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final n in recent) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: LotoBall(n: n, size: 44))]),
        if (live['paused'] == true) ...[
          const SizedBox(height: 12),
          Text('Pause', textAlign: TextAlign.center, style: Pb.t(22, weight: 700, color: Pb.yellow)),
        ],
        const Spacer(),
        if (!widget.isHost)
          Text('Marque tes numéros sur ton carton. Tu as gagné ? Crie-le, l’hôte vérifie !', textAlign: TextAlign.center, style: Pb.t(16, color: Pb.muted))
        else if (ph == 'check') ...[
          Text('Vérifiez le carton avec les numéros sortis sur la TV', textAlign: TextAlign.center, style: Pb.t(16, color: Pb.muted)),
          const SizedBox(height: 10),
          TextField(
            controller: _winner,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Prénom du gagnant (facultatif)', counterText: ''),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Pb.green, foregroundColor: Pb.bg),
              onPressed: () {
                HapticFeedback.heavyImpact();
                _g({'t': 'loto_verdict', 'ok': true, 'name': _winner.text});
                _winner.clear();
              },
              child: Text('C’est gagné : ${prize?['title'] ?? ''} !', style: Pb.t(21, weight: 700, color: Pb.bg)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: () => _g({'t': 'loto_verdict', 'ok': false}),
              child: const Text('Faux, on continue'),
            ),
          ),
        ] else if (ph == 'draw' && live['paused'] != true)
          SizedBox(
            height: 72,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Pb.yellow, foregroundColor: Pb.bg),
              onPressed: () {
                HapticFeedback.heavyImpact();
                _g({'t': 'loto_check'});
              },
              child: Text('📢 Quelqu’un a crié ! Vérifier', style: Pb.t(22, weight: 700, color: Pb.bg)),
            ),
          ),
      ]),
    );
  }

  Widget _cartons({required bool interactive}) {
    final cards = [for (final c in (widget.you?['cards'] as List? ?? const [])) (no: ((c as Map)['no'] as num).toInt(), grid: _grid(c['grid']))];
    final marks = {for (final n in (widget.you?['marks'] as List? ?? const [])) (n as num).toInt()};
    final auto = widget.live['auto'] == true;
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth.clamp(200.0, 420.0) : 358.0;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final (i, g) in cards.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          LotoCarton(
            grid: g.grid,
            no: g.no,
            series: widget.live.i('series'),
            marks: marks,
            width: w,
            tint: i == 0 ? _green : const Color(0xFF2D7FE0),
            onTap: interactive && !auto
                ? (n) {
                    HapticFeedback.selectionClick();
                    _g({'t': 'loto_mark', 'n': n});
                  }
                : null,
          ),
        ],
      ]);
    });
  }

  // Choisir son ou ses cartons : sa liste de 20 défile de haut en bas, on coche, puis « Commencer »
  Widget _choose() {
    final live = widget.live;
    final pool = [for (final c in (widget.you?['pool'] as List? ?? const [])) (no: ((c as Map)['no'] as num).toInt(), grid: _grid(c['grid']))];
    final need = live.i('perPlayer');
    final mine = [for (final c in (widget.you?['cards'] as List? ?? const [])) ((c as Map)['no'] as num).toInt()];
    final ready = widget.you.yb('ready');
    final enough = mine.length == need;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(right: 44),
          child: Text(need == 2 ? 'Coche tes 2 cartons' : 'Coche ton carton', style: Pb.t(26, weight: 700, color: Pb.yellow)),
        ),
        Text('${pool.length} cartons rien qu’à toi · ${mine.length}/$need coché${need > 1 ? 's' : ''}', style: Pb.t(15, color: Pb.muted)),
        const SizedBox(height: 8),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 5),
        const SizedBox(height: 10),
        Expanded(
          child: Builder(
            builder: (_) => ListView.separated(
              itemCount: pool.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final c = pool[i];
                final on = mine.contains(c.no);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _g({'t': 'loto_pick', 'no': c.no});
                  },
                  child: Row(children: [
                    // La case à cocher
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: on ? Pb.green : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: on ? Pb.green : _red, width: 3),
                      ),
                      child: on ? const Icon(Icons.check_rounded, color: Pb.bg, size: 24) : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, b) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: on ? Pb.green : Colors.transparent, width: 3),
                          ),
                          child: LotoCarton(grid: c.grid, no: c.no, series: live.i('series'), marks: const {}, width: b.maxWidth - 12),
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ready
              ? OutlinedButton(
                  onPressed: null,
                  child: Text('Prêt ! On attend les autres…', style: Pb.t(20, weight: 700, color: Pb.green)),
                )
              : FilledButton(
                  onPressed: enough
                      ? () {
                          HapticFeedback.mediumImpact();
                          _g({'t': 'loto_ready'});
                        }
                      : null,
                  child: Text(enough ? 'Commencer' : 'Coche encore ${need - mine.length} carton${need - mine.length > 1 ? 's' : ''}', style: Pb.t(22, weight: 700)),
                ),
        ),
      ]),
    );
  }

  Widget _game() {
    final live = widget.live;
    final last = (live['last'] as num?)?.toInt();
    final prize = live['prize'] as Map?;
    final auto = live['auto'] == true;
    final ev = live['event'] as Map?;
    final win = live.phase == 'win' && ev?['k'] == 'win';
    final winners = win ? [for (final p in (ev!['pids'] as List? ?? const [])) p as String] : const <String>[];
    final iWon = winners.contains(widget.myPid);
    final recent = [for (final n in (live['drawn'] as List? ?? const []).reversed.skip(1).take(4)) (n as num).toInt()];

    final page = Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (last != null) LotoBall(n: last, size: 84) else const SizedBox(width: 84, height: 84),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (live.s('nick') != null) Text('« ${live.s('nick')} »', style: Pb.t(16, weight: 600, color: Pb.yellow)),
              if (prize != null) Text('On joue : ${prize['title']}', style: Pb.t(20, weight: 700)),
              const SizedBox(height: 6),
              Row(children: [for (final n in recent) Padding(padding: const EdgeInsets.only(right: 6), child: LotoBall(n: n, size: 34))]),
            ]),
          ),
        ]),
        if (live['paused'] == true)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Pb.yellow, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.pause_rounded, color: Pb.bg),
              const SizedBox(width: 6),
              Text('Pause', style: Pb.t(18, weight: 700, color: Pb.bg)),
            ]),
          )
        else if (live.phase == 'draw') ...[const SizedBox(height: 8), TimeBar(endsIn: live.endsIn, duration: live.duration, height: 5)],
        const SizedBox(height: 12),
        if (win)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Pb.yellow, borderRadius: BorderRadius.circular(16)),
            child: Text(
              iWon ? '${_prizeShout(ev!['prize'] as String?)} Bravo !' : '${_prizeShout(ev!['prize'] as String?)} pour ${[for (final p in winners) widget.room.player(p)?.name ?? '?'].join(', ')}',
              textAlign: TextAlign.center,
              style: Pb.t(20, weight: 700, color: Pb.bg),
            ),
          ),
        Expanded(child: SingleChildScrollView(child: _cartons(interactive: true))),
        const SizedBox(height: 10),
        if (!auto && prize != null) _claimButton(prize['id'] as String?),
        if (auto) Text('Marquage automatique', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.muted)),
      ]),
    );
    if (!iWon) return page;
    return Stack(children: [page, const Positioned.fill(child: IgnorePointer(child: Fireworks(seconds: 4)))]);
  }

  Widget _claimButton(String? prizeId) {
    final left = _lockedUntil.difference(DateTime.now());
    if (left > Duration.zero) {
      // Se réaffiche tout seul à la fin du blocage
      Future.delayed(left, () {
        if (mounted) setState(() {});
      });
      return SizedBox(
        height: 70,
        child: FilledButton(onPressed: null, child: Text('Faux ! Attends ${left.inSeconds + 1} s', style: Pb.t(22, weight: 700))),
      );
    }
    return SizedBox(
      height: 70,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Pb.yellow, foregroundColor: Pb.bg),
        onPressed: () {
          HapticFeedback.heavyImpact();
          _g({'t': 'loto_claim'});
        },
        child: Text(_prizeShout(prizeId), style: Pb.t(28, weight: 700, color: Pb.bg)),
      ),
    );
  }
}
