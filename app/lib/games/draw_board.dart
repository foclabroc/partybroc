import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Couleurs du dessin (même nombre que côté serveur : 12)
const drawColors = <Color>[
  Color(0xFF1A1A1A), Color(0xFFFFFFFF), Color(0xFF9E9E9E), Color(0xFFE53935),
  Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF29B6F6),
  Color(0xFF1E40AF), Color(0xFF8E24AA), Color(0xFFF06292), Color(0xFF795548),
];

/// Épaisseurs proposées (en millièmes de la largeur du dessin)
const drawWidths = <int>[6, 14, 30];

class Stroke {
  Stroke(this.id, this.color, this.width, [List<int>? pts]) : pts = pts ?? [];
  final int id;
  final int color;
  final int width;
  final List<int> pts; // x0, y0, x1, y1… entre 0 et 1000
}

/// Le dessin en cours, partagé par l'écran (TV ou téléphone) et alimenté par
/// les messages « draw » du serveur. Un seul dessin à la fois.
class DrawBoard extends ChangeNotifier {
  static final instance = DrawBoard();

  int turn = -1;
  final List<Stroke> strokes = [];
  void Function()? requestSync;
  DateTime _lastAsk = DateTime(2000);

  void _ask() {
    if (DateTime.now().difference(_lastAsk) < const Duration(seconds: 2)) return;
    _lastAsk = DateTime.now();
    requestSync?.call();
  }

  /// Message « draw » reçu du serveur
  void apply(Map<String, dynamic> m) {
    final t = (m['turn'] as num?)?.toInt() ?? -1;
    switch (m['op']) {
      case 'clear':
        turn = t;
        strokes.clear();
      case 'full':
        turn = t;
        strokes
          ..clear()
          ..addAll([
            for (final s in (m['strokes'] as List?) ?? const [])
              Stroke((s['s'] as num).toInt(), (s['c'] as num).toInt(), (s['w'] as num).toInt(),
                  [for (final v in s['p'] as List) (v as num).toInt()]),
          ]);
      case 'pts':
        if (t != turn) return _ask(); // on a raté le début de ce tour
        final id = (m['s'] as num).toInt();
        var st = strokes.where((x) => x.id == id).firstOrNull;
        if (st == null) {
          st = Stroke(id, (m['c'] as num).toInt(), (m['w'] as num).toInt());
          strokes.add(st);
        }
        st.pts.addAll([for (final v in m['p'] as List) (v as num).toInt()]);
      case 'undo':
        if (t != turn) return _ask();
        final id = (m['s'] as num).toInt();
        strokes.removeWhere((x) => x.id == id);
      default:
        return;
    }
    notifyListeners();
  }

  /// Vérifie qu'on a bien tout le dessin (après un rechargement, une coupure…)
  void ensure(int serverTurn, int serverStrokes) {
    if (serverTurn != turn || strokes.length < serverStrokes) {
      scheduleMicrotask(_ask);
    }
  }

  // ---- côté dessinateur (traits locaux, envoyés en parallèle) ----
  void localStart(Stroke s) {
    strokes.add(s);
    notifyListeners();
  }

  void localAdd(Stroke s, int x, int y) {
    s.pts..add(x)..add(y);
    notifyListeners();
  }

  void localUndo() {
    if (strokes.isNotEmpty) strokes.removeLast();
    notifyListeners();
  }

  void localClear() {
    strokes.clear();
    notifyListeners();
  }
}

class DrawPainter extends CustomPainter {
  DrawPainter(this.board) : super(repaint: board);
  final DrawBoard board;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final k = size.width / 1000;
    for (final s in board.strokes) {
      if (s.pts.length < 2) continue;
      final paint = Paint()
        ..color = drawColors[s.color % drawColors.length]
        ..strokeWidth = math.max(1.5, s.width * k)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.pts.length == 2) {
        canvas.drawCircle(Offset(s.pts[0] * k, s.pts[1] * k), paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(s.pts[0] * k, s.pts[1] * k);
      for (var i = 2; i + 1 < s.pts.length; i += 2) {
        path.lineTo(s.pts[i] * k, s.pts[i + 1] * k);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(DrawPainter old) => false;
}

/// Le dessin affiché (TV ou téléphone des devineurs)
class DrawView extends StatelessWidget {
  const DrawView({super.key, this.radius = 24});
  final double radius;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CustomPaint(painter: DrawPainter(DrawBoard.instance), size: Size.infinite),
        ),
      );
}

/// La zone de dessin du dessinateur : trace localement et envoie les points
/// au serveur par petits paquets (toutes les 50 ms).
class DrawPad extends StatefulWidget {
  const DrawPad({super.key, required this.color, required this.width, required this.send});
  final int color;
  final int width;
  final void Function(Map<String, dynamic> m) send;

  @override
  State<DrawPad> createState() => _DrawPadState();
}

class _DrawPadState extends State<DrawPad> {
  final _board = DrawBoard.instance;
  int _nextId = DateTime.now().millisecondsSinceEpoch % 1000000;
  Stroke? _cur;
  final List<int> _pending = [];
  Timer? _flush;

  @override
  void initState() {
    super.initState();
    _flush = Timer.periodic(const Duration(milliseconds: 50), (_) => _send());
  }

  @override
  void dispose() {
    _send();
    _flush?.cancel();
    super.dispose();
  }

  void _send() {
    final s = _cur;
    if (s == null || _pending.isEmpty) return;
    widget.send({'t': 'drw_stroke', 's': s.id, 'c': s.color, 'w': s.width, 'p': List<int>.of(_pending)});
    _pending.clear();
  }

  (int, int) _pt(Offset local, double side) =>
      ((local.dx / side * 1000).round().clamp(0, 1000), (local.dy / side * 1000).round().clamp(0, 1000));

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, c) {
        final side = c.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: GestureDetector(
            onPanStart: (d) {
              _send();
              final (x, y) = _pt(d.localPosition, side);
              _cur = Stroke(_nextId++, widget.color, widget.width);
              _board.localStart(_cur!);
              _board.localAdd(_cur!, x, y);
              _pending..add(x)..add(y);
            },
            onPanUpdate: (d) {
              final s = _cur;
              if (s == null) return;
              final (x, y) = _pt(d.localPosition, side);
              // On saute les points trop proches (moins de données à envoyer)
              final n = s.pts.length;
              if (n >= 2 && (s.pts[n - 2] - x).abs() + (s.pts[n - 1] - y).abs() < 4) return;
              _board.localAdd(s, x, y);
              _pending..add(x)..add(y);
            },
            onPanEnd: (_) {
              _send();
              _cur = null;
            },
            child: CustomPaint(painter: DrawPainter(_board), size: Size.infinite),
          ),
        );
      }),
    );
  }
}
