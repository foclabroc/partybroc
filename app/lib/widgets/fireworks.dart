import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// Feu d'artifice + confettis par-dessus le podium. Léger (quelques centaines de
/// particules au plus) pour tenir sur une TV Android modeste. Ne capte aucun appui.
class Fireworks extends StatefulWidget {
  const Fireworks({super.key, this.seconds = 9, this.confetti = true});
  final int seconds; // durée des tirs (les dernières particules finissent ensuite)
  final bool confetti;

  @override
  State<Fireworks> createState() => _FireworksState();
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.color, this.life, {this.rocket = false, this.size = 5, this.spin = 0});
  double x, y, vx, vy;
  final Color color;
  double life; // secondes restantes
  final bool rocket;
  final double size;
  double spin;
  double age = 0;
}

class _FireworksState extends State<Fireworks> with SingleTickerProviderStateMixin {
  final _rnd = Random();
  final _parts = <_Particle>[];
  final _confetti = <_Particle>[];
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;
  double _nextRocket = 0.2;
  Size _size = Size.zero;

  static const _colors = [Pb.pink, Pb.yellow, Pb.cyan, Pb.green, Color(0xFFFF8A3D), Color(0xFFC86BFF), Colors.white];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (_size == Size.zero) return;
    _t += dt;
    final w = _size.width, h = _size.height;

    // Nouvelles fusées pendant [seconds]
    if (_t < widget.seconds && _t >= _nextRocket) {
      _nextRocket = _t + 0.35 + _rnd.nextDouble() * 0.55;
      _parts.add(_Particle(w * (0.12 + _rnd.nextDouble() * 0.76), h + 10, (_rnd.nextDouble() - .5) * w * .08, -h * (0.95 + _rnd.nextDouble() * 0.35),
          _colors[_rnd.nextInt(_colors.length)], 0.75 + _rnd.nextDouble() * 0.35, rocket: true, size: w * .004));
    }
    // Confettis qui tombent du haut pendant les 6 premières secondes
    if (widget.confetti && _t < 6 && _confetti.length < 160) {
      for (var i = 0; i < 3; i++) {
        _confetti.add(_Particle(_rnd.nextDouble() * w, -20, (_rnd.nextDouble() - .5) * w * .05, h * (.12 + _rnd.nextDouble() * .12),
            _colors[_rnd.nextInt(_colors.length)], 9, size: w * (.005 + _rnd.nextDouble() * .006), spin: _rnd.nextDouble() * 6));
      }
    }

    final g = h * 0.55; // gravité
    final born = <_Particle>[];
    for (final p in _parts) {
      p.age += dt;
      p.life -= dt;
      p.vy += (p.rocket ? g * .45 : g * .35) * dt;
      if (!p.rocket) {
        p.vx *= 1 - 1.4 * dt;
        p.vy *= 1 - 1.4 * dt;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      // La fusée explose : une gerbe de 60 à 90 étincelles
      if (p.rocket && (p.life <= 0 || p.vy > -h * .05)) {
        p.life = 0;
        final n = 60 + _rnd.nextInt(30);
        final speed = w * (0.22 + _rnd.nextDouble() * 0.12);
        final c2 = _colors[_rnd.nextInt(_colors.length)];
        for (var i = 0; i < n; i++) {
          final a = i / n * 2 * pi + _rnd.nextDouble() * .1;
          final s = speed * (0.55 + _rnd.nextDouble() * 0.45);
          born.add(_Particle(p.x, p.y, cos(a) * s, sin(a) * s, i.isEven ? p.color : c2, 1.1 + _rnd.nextDouble() * 0.7, size: w * .0032));
        }
      }
    }
    _parts.removeWhere((p) => p.life <= 0);
    _parts.addAll(born);
    if (_parts.length > 700) _parts.removeRange(0, _parts.length - 700);

    for (final c in _confetti) {
      c.age += dt;
      c.x += (c.vx + sin(c.age * 3 + c.spin) * w * .02) * dt;
      c.y += c.vy * dt;
      c.spin += dt * 4;
    }
    _confetti.removeWhere((c) => c.y > h + 30);

    if (_t > widget.seconds + 3 && _parts.isEmpty && _confetti.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return CustomPaint(size: _size, painter: _Painter(_parts, _confetti));
      }),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.parts, this.confetti);
  final List<_Particle> parts, confetti;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in parts) {
      if (p.rocket) {
        paint.color = Colors.white.withValues(alpha: .9);
        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
        paint.color = p.color.withValues(alpha: .5);
        canvas.drawCircle(Offset(p.x - p.vx * .02, p.y - p.vy * .02), p.size * .8, paint);
      } else {
        final a = (p.life / 1.2).clamp(0.0, 1.0);
        paint.color = p.color.withValues(alpha: a);
        canvas.drawCircle(Offset(p.x, p.y), p.size * (0.6 + a * 0.6), paint);
      }
    }
    for (final c in confetti) {
      paint.color = c.color;
      canvas.save();
      canvas.translate(c.x, c.y);
      canvas.rotate(c.spin);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: c.size * 2, height: c.size * (0.6 + 0.6 * sin(c.spin * 2).abs())), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}
