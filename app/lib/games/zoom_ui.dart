import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// L'emoji géant qui se dézoome au fil du temps (calé sur le chrono du serveur).
/// À la révélation : affiché en entier.
class ZoomPicture extends StatefulWidget {
  const ZoomPicture({super.key, required this.e, required this.fx, required this.fy, required this.endsIn, required this.duration, required this.full, this.size = 620});
  final String e;
  final double fx, fy;
  final int endsIn, duration;
  final bool full;
  final double size;

  @override
  State<ZoomPicture> createState() => _ZoomPictureState();
}

class _ZoomPictureState extends State<ZoomPicture> with SingleTickerProviderStateMixin {
  // L'emoji est dessiné UNE fois dans une image ; à chaque image de l'animation on ne
  // recopie que la partie visible (avant : un emoji de 7000 pixels redessiné 60 fois par
  // seconde, la TV ramait).
  static const _n = 1024;
  late DateTime _end;
  late final Ticker _ticker;
  final _scale = ValueNotifier<double>(16);
  ui.Image? _img;
  DateTime? _fullAt;
  Offset? _focus; // point zoomé, posé sur un morceau de l'emoji (pas sur du blanc)

  // Le point demandé par le serveur tombe parfois dans le vide (le creux d'un croissant
  // de lune…) : on prend le point de l'emoji le plus proche (même calcul partout)
  static Future<Offset> _focusOn(ui.Image img, double fx, double fy) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return Offset(fx, fy);
    final n = img.width;
    const step = 8;
    bool solid(int x, int y) => data.getUint8((y * n + x) * 4 + 3) > 200;
    final cx = (fx * n).round().clamp(0, n - 1), cy = (fy * n).round().clamp(0, n - 1);
    if (solid(cx, cy)) return Offset(fx, fy);
    Offset? best;
    var bestD = double.infinity;
    for (var y = 0; y < n; y += step) {
      for (var x = 0; x < n; x += step) {
        if (!solid(x, y)) continue;
        final d = ((x - cx) * (x - cx) + (y - cy) * (y - cy)).toDouble();
        if (d < bestD) {
          bestD = d;
          best = Offset(x / n, y / n);
        }
      }
    }
    return best ?? Offset(fx, fy);
  }
  double _fullFrom = 1;

  @override
  void initState() {
    super.initState();
    _end = DateTime.now().add(Duration(milliseconds: widget.endsIn));
    _ticker = createTicker((_) => _tick())..start();
    _tick();
    _raster();
    // Sur le web, la police des emojis arrive parfois après le premier dessin (carré vide) :
    // on redessine l'image dès qu'elle est chargée, et encore un peu plus tard par sécurité
    PaintingBinding.instance.systemFonts.addListener(_raster);
    for (final ms in const [700, 2000, 5000]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted) _raster();
      });
    }
  }

  Future<void> _raster() async {
    final e = widget.e;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final tp = TextPainter(
      text: TextSpan(text: e, style: const TextStyle(fontSize: _n * .72, height: 1.15)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((_n - tp.width) / 2, (_n - tp.height) / 2));
    final img = await rec.endRecording().toImage(_n, _n);
    final focus = await _focusOn(img, widget.fx, widget.fy);
    if (!mounted || e != widget.e) {
      img.dispose();
      return;
    }
    setState(() {
      _img?.dispose();
      _img = img;
      _focus = focus;
    });
  }

  void _tick() {
    final w = widget;
    if (w.full) {
      _fullAt ??= DateTime.now();
      final k = (DateTime.now().difference(_fullAt!).inMilliseconds / 700).clamp(0.0, 1.0);
      _scale.value = _fullFrom + (1 - _fullFrom) * Curves.easeOutCubic.transform(k);
      if (k >= 1 && _ticker.isActive) _ticker.stop();
      return;
    }
    final left = _end.difference(DateTime.now()).inMilliseconds.clamp(0, w.duration);
    // 0 au début → 1 à la fin ; le zoom part de ×16 et descend vers ×1,4 (jamais en entier avant la fin)
    final t = w.duration == 0 ? 1.0 : 1 - left / w.duration;
    _scale.value = 1.4 + 14.6 * pow(1 - t, 2.2);
    _fullFrom = _scale.value;
  }

  @override
  void didUpdateWidget(ZoomPicture old) {
    super.didUpdateWidget(old);
    final fresh = DateTime.now().add(Duration(milliseconds: widget.endsIn));
    if (fresh.difference(_end).inMilliseconds.abs() > 400) _end = fresh;
    if (widget.e != old.e) _raster();
    if (widget.full && !old.full) {
      _fullAt = null;
      if (!_ticker.isActive) _ticker.start();
    }
    _tick();
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_raster);
    _ticker.dispose();
    _scale.dispose();
    _img?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(s * .08),
        border: Border.all(color: Pb.cardHi, width: s * .015),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: s * .06)],
      ),
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ZoomPainter(_img, _scale, _focus?.dx ?? widget.fx, _focus?.dy ?? widget.fy),
        ),
      ),
    );
  }
}

class _ZoomPainter extends CustomPainter {
  _ZoomPainter(this.img, this.scale, this.fx, this.fy) : super(repaint: scale);
  final ui.Image? img;
  final ValueNotifier<double> scale;
  final double fx, fy;

  @override
  void paint(Canvas canvas, Size size) {
    final im = img;
    if (im == null) return;
    // Zoom autour du point (fx, fy) : partie visible de l'image = 1/scale de sa taille
    final n = im.width.toDouble();
    final k = scale.value;
    final w = n / k;
    final src = Rect.fromLTWH(fx * n * (1 - 1 / k), fy * n * (1 - 1 / k), w, w);
    canvas.drawImageRect(im, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_ZoomPainter old) => old.img != img || old.fx != fx || old.fy != fy;
}

/// Zoom mystère sur la TV
class ZoomTv extends StatelessWidget {
  const ZoomTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🔍',
          title: 'Zoom mystère',
          sub: '${live.i('count')} images',
          rules: const ['L’image est très zoomée, puis elle se dézoome petit à petit.', 'Un seul essai : plus tu trouves tôt, plus tu marques !'],
          live: live),
      'ask' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'reveal' ? 'ask' : ph}-${live.i('index')}', child: body);
  }

  Widget _round() {
    final reveal = live.phase == 'reveal';
    final picks = {for (final e in ((live['picks'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()};
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Image', index: live.i('index'), count: live.i('count'), live: reveal ? null : live),
        const SizedBox(height: 20),
        Expanded(
          child: Row(children: [
            ZoomPicture(
              key: ValueKey('z${live.i('index')}'),
              e: live.s('e') ?? '❓',
              fx: (live['fx'] as num?)?.toDouble() ?? .5,
              fy: (live['fy'] as num?)?.toDouble() ?? .5,
              endsIn: live.endsIn,
              duration: live.duration,
              full: reveal,
            ),
            const SizedBox(width: 60),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(reveal ? 'C’était…' : 'Qu’est-ce que c’est ?', style: Pb.t(60, weight: 700)),
                const SizedBox(height: 36),
                TvChoices(room: room, choices: live.pids('choices'), correct: reveal ? live.i('correct') : null, picks: picks, height: 120),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 90,
          child: reveal ? TvGains(room: room, ranking: live.ranking) : TvWhoDone(room: room, done: live.pids('answered').toSet()),
        ),
      ]),
    );
  }
}

/// Zoom mystère sur le téléphone
class ZoomPlay extends StatelessWidget {
  const ZoomPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🔍', title: 'Zoom mystère', sub: 'Regarde l’image sur la TV et trouve ce que c’est. Un seul essai !'),
      'ask' => Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
            const SizedBox(height: 14),
            Text('Qu’est-ce que c’est ? 🔍', textAlign: TextAlign.center, style: Pb.t(22, weight: 700)),
            const SizedBox(height: 14),
            Expanded(
              child: PhoneChoices(
                choices: live.pids('choices'),
                picked: you.yi('answer'),
                onPick: (i) => send({'t': 'game_msg', 'm': {'t': 'zoom_pick', 'r': live.i('index'), 'choice': i}}),
              ),
            ),
          ]),
        ),
      'reveal' => phoneGain(you, good: 'Bien vu ! 👀', none: 'Raté !'),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }
}
