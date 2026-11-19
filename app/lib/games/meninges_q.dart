import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Bataille de méninges : une question sur le téléphone (les 7 formes : pick, num, seq, coins,
/// multi, whack, cups) et ses dessins (`pic`). Envoie la réponse avec [onAnswer].
/// Une étape « à retenir » (`show`, `flash`, gobelets) passe d'abord si la question en a une.
class MngQuestion extends StatefulWidget {
  const MngQuestion({super.key, required this.q, required this.locked, required this.onAnswer});
  final Map<String, dynamic> q;
  final bool locked; // erreur : bloqué un instant
  final void Function(Object v) onAnswer;

  @override
  State<MngQuestion> createState() => _MngQuestionState();
}

class _MngQuestionState extends State<MngQuestion> {
  bool _showing = false;
  bool _sent = false;
  Timer? _timer;
  // saisies en cours
  String _typed = '';
  final _picked = <int>[];
  int? _flashOn; // case allumée (les cases)

  Map<String, dynamic> get q => widget.q;
  String get k => q['k'] as String? ?? 'pick';
  List<Map<String, dynamic>> _list(String key) => [for (final x in (q[key] as List? ?? const [])) (x as Map).cast<String, dynamic>()];

  @override
  void initState() {
    super.initState();
    if (q['show'] != null) {
      _showing = true;
      _timer = Timer(Duration(milliseconds: (q['showMs'] as num?)?.toInt() ?? 2000), () => setState(() => _showing = false));
    } else if (q['flash'] != null) {
      _showing = true;
      _runFlash();
    }
  }

  void _runFlash() async {
    final seq = [for (final x in q['flash'] as List) (x as num).toInt()];
    final ms = (q['flashMs'] as num?)?.toInt() ?? 550;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    for (final c in seq) {
      if (!mounted) return;
      setState(() => _flashOn = c);
      await Future<void>.delayed(Duration(milliseconds: ms));
      if (!mounted) return;
      setState(() => _flashOn = null);
      await Future<void>.delayed(Duration(milliseconds: (ms * .35).round()));
    }
    if (mounted) setState(() => _showing = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _send(Object v) {
    if (_sent || widget.locked) return;
    _sent = true;
    HapticFeedback.selectionClick();
    widget.onAnswer(v);
  }

  @override
  Widget build(BuildContext context) {
    final prompt = q['prompt'] as String? ?? '';
    final pic = q['pic'] as Map?;
    final Widget body;
    if (_showing && q['show'] != null) {
      body = Column(children: [
        Text('Retiens bien !', style: Pb.t(22, weight: 700, color: Pb.yellow)),
        const SizedBox(height: 8),
        Expanded(child: Center(child: MngPic(pic: (q['show'] as Map).cast<String, dynamic>()))),
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_showing ? 'Regarde bien…' : prompt, textAlign: TextAlign.center, style: Pb.t(21, weight: 700)),
        const SizedBox(height: 8),
        if (pic != null && k != 'cups') ...[
          Flexible(flex: q['picBig'] == true ? 6 : 4, child: Center(child: MngPic(pic: pic.cast<String, dynamic>()))),
          const SizedBox(height: 10),
        ],
        Expanded(flex: q['picBig'] == true ? 4 : 6, child: _input()),
      ]);
    }
    return AbsorbPointer(absorbing: widget.locked || _sent, child: body);
  }

  Widget _input() => switch (k) {
        'num' => _num(),
        'seq' => _seq(),
        'coins' => _coins(),
        'multi' || 'whack' => _taps(),
        'cups' => MngCups(q: q, onPick: (i) => _send(i)),
        _ => _pick(),
      };

  // ---- un choix parmi plusieurs ----
  Widget _pick() {
    final choices = _list('choices');
    final cols = (q['cols'] as num?)?.toInt() ?? 2;
    final ask = q['ask'] as String?; // « Où était 🐱 ? » : cases vides à toucher
    return _grid(choices.length, cols, (i) {
      final c = choices[i];
      return _tile(
        color: c['c'] != null ? Color((c['c'] as num).toInt()) : (ask != null ? Pb.card : Pb.answerColors[i % 4]),
        onTap: () => _send(i),
        child: _choiceContent(c, big: cols <= 2 && choices.length <= 4),
      );
    });
  }

  Widget _choiceContent(Map<String, dynamic> c, {bool big = false}) {
    final e = c['e'] as String?;
    final t = c['t'] as String?;
    if (e != null && e.isNotEmpty) {
      Widget w = Text(e, style: TextStyle(fontSize: 64 * ((c['s'] as num?)?.toDouble() ?? 1)));
      if (c['fx'] == true) w = Transform.flip(flipX: true, child: w);
      final rot = (c['rot'] as num?)?.toDouble() ?? 0;
      if (rot != 0) w = Transform.rotate(angle: rot * math.pi / 180, child: w);
      if (c['sil'] == true) w = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn), child: w);
      return FittedBox(child: Padding(padding: const EdgeInsets.all(6), child: w));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(t ?? '', textAlign: TextAlign.center, style: Pb.t(big ? 30 : 24, weight: 700, color: Colors.white))),
    );
  }

  // ---- pavé de chiffres ----
  Widget _num() {
    final max = (q['maxLen'] as num?)?.toInt() ?? 5;
    void key(String s) {
      if (s == '⌫') {
        if (_typed.isNotEmpty) setState(() => _typed = _typed.substring(0, _typed.length - 1));
      } else if (s == 'OK') {
        if (_typed.isNotEmpty) _send(int.tryParse(_typed) ?? -1);
      } else if (_typed.length < max) {
        setState(() => _typed += s);
      }
    }

    return Column(children: [
      Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(14)),
        child: Text(_typed.isEmpty ? '…' : _typed, style: Pb.t(36, weight: 700, color: _typed.isEmpty ? Pb.muted : Pb.text)),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _grid(12, 3, (i) {
          final s = const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'OK'][i];
          return _tile(color: s == 'OK' ? Pb.green : Pb.card, onTap: () => key(s), child: Text(s, style: Pb.t(28, weight: 700, color: s == 'OK' ? const Color(0xFF06301A) : Pb.text)));
        }, gap: 7),
      ),
    ]);
  }

  // ---- toucher dans l'ordre (cases, nombres, lettres, syllabes) ----
  Widget _seq() {
    final items = _list('items');
    final n = (q['n'] as num?)?.toInt() ?? items.length;
    final tiles = q['tiles'] == true;
    final ordered = q['ordered'] == true;
    final mark = q['mark'] == true;
    final simon = q['simon'] == true;
    void tap(int i) {
      if (_showing) return;
      if (tiles && _picked.contains(i)) return;
      if (ordered) {
        // nombres : on sait tout de suite si c'est le bon
        final rest = [for (var j = 0; j < items.length; j++) if (!_picked.contains(j)) int.tryParse('${items[j]['t']}') ?? 0];
        final v = int.tryParse('${items[i]['t']}') ?? 0;
        if (_picked.contains(i)) return;
        setState(() => _picked.add(i));
        if (v != rest.reduce(math.min)) return _send([..._picked]);
      } else {
        if (mark && _picked.contains(i)) return;
        setState(() => _picked.add(i));
      }
      if (_picked.length >= n) _send([..._picked]);
    }

    if (tiles) {
      // lettres / syllabes : les cases du mot en haut, les morceaux à toucher en dessous
      return Column(children: [
        Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
          for (var s = 0; s < n; s++)
            Container(
              constraints: const BoxConstraints(minWidth: 38),
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(10)),
              child: Center(widthFactor: 1, child: Text(s < _picked.length ? '${items[_picked[s]]['t']}' : '', style: Pb.t(26, weight: 700))),
            ),
        ]),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < items.length; i++)
            Opacity(
              opacity: _picked.contains(i) ? .2 : 1,
              child: Material(
                color: const Color(0xFF16A3B8),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => tap(i),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 58),
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(widthFactor: 1, child: Text('${items[i]['t']}', style: Pb.t(28, weight: 700, color: Colors.white))),
                  ),
                ),
              ),
            ),
        ]),
        const Spacer(),
        if (_picked.isNotEmpty)
          TextButton.icon(onPressed: () => setState(_picked.clear), icon: const Icon(Icons.undo_rounded), label: const Text('Recommencer')),
      ]);
    }
    final cols = (q['cols'] as num?)?.toInt() ?? 3;
    return _grid(items.length, cols, (i) {
      final it = items[i];
      final lit = _flashOn == i;
      final done = _picked.contains(i);
      final dim = (ordered || mark) && done;
      final base = it['c'] != null ? Color((it['c'] as num).toInt()) : Pb.card;
      return _tile(
        color: lit ? (simon ? Color.lerp(base, Colors.white, .7)! : Pb.yellow) : (dim ? Pb.bg2 : base.withValues(alpha: it['c'] != null ? (_showing ? .35 : .8) : 1)),
        onTap: () => tap(i),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(it['t'] as String? ?? '', style: Pb.t(30, weight: 700, color: dim ? Pb.muted : Colors.white)),
          ),
        ),
      );
    });
  }

  // ---- la monnaie ----
  Widget _coins() {
    final coins = [for (final x in q['coins'] as List) (x as num).toInt()];
    final target = (q['target'] as num).toInt();
    final sum = _picked.fold<int>(0, (s, i) => s + coins[i]);
    String eur(int c) => c == 0 ? '0 €' : c >= 100 ? '${c ~/ 100}${c % 100 == 0 ? '' : ',${(c % 100).toString().padLeft(2, '0')}'} €' : '$c c';
    void tap(int i) {
      if (_picked.contains(i)) {
        setState(() => _picked.remove(i));
        return;
      }
      setState(() => _picked.add(i));
      final s = _picked.fold<int>(0, (a, j) => a + coins[j]);
      if (s >= target) _send([..._picked]);
    }

    return Column(children: [
      Text('${eur(sum)} / ${eur(target)}', style: Pb.t(26, weight: 700, color: sum == target ? Pb.green : Pb.yellow)),
      const SizedBox(height: 10),
      Expanded(
        child: _grid(coins.length, 3, (i) {
          final c = coins[i];
          final gold = c >= 10 && c < 100 || c == 200;
          final sel = _picked.contains(i);
          return GestureDetector(
            onTap: () => tap(i),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: sel ? .82 : 1,
              child: Opacity(
                opacity: sel ? .45 : 1,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: gold ? const [Color(0xFFFFE98A), Color(0xFFD4A017)] : const [Color(0xFFF0C9A0), Color(0xFFB06A33)]),
                        border: Border.all(color: c >= 100 ? const Color(0xFFC0C0C8) : Colors.black26, width: c >= 100 ? 6 : 3),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(child: Padding(padding: const EdgeInsets.all(10), child: Text(eur(c), style: Pb.t(22, weight: 700, color: const Color(0xFF3A2400))))),
                    ),
                  ),
                ),
              ),
            ),
          );
        }, gap: 8),
      ),
    ]);
  }

  // ---- en toucher plusieurs (jumeaux, taupes) ----
  Widget _taps() {
    final items = _list('items');
    final cols = (q['cols'] as num?)?.toInt() ?? 3;
    final whack = k == 'whack';
    final target = q['target'] as String? ?? '🐹';
    final need = whack ? items.where((it) => it['e'] == target).length : (q['n'] as num?)?.toInt() ?? 2;
    void tap(int i) {
      if (_picked.contains(i)) {
        if (!whack) setState(() => _picked.remove(i));
        return;
      }
      if (whack && (items[i]['e'] as String? ?? '').isEmpty) return;
      setState(() => _picked.add(i));
      if (whack && items[i]['e'] != target) return _send([..._picked]);
      if (_picked.length >= need) _send([..._picked]);
    }

    return _grid(items.length, cols, (i) {
      final e = items[i]['e'] as String? ?? '';
      final sel = _picked.contains(i);
      return _tile(
        color: sel ? (whack ? Pb.bg2 : Pb.yellow.withValues(alpha: .5)) : (whack && target == '🐹' ? const Color(0xFF5B3A1E) : Pb.card),
        onTap: () => tap(i),
        child: whack
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(sel ? (e == target ? '💥' : '😵') : e, key: ValueKey('$i$sel'), style: const TextStyle(fontSize: 46)),
              )
            : FittedBox(child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 46)))),
      );
    });
  }

  // ---- outils ----
  Widget _grid(int n, int cols, Widget Function(int i) cell, {double gap = 9}) {
    final rows = (n / cols).ceil();
    return Column(children: [
      for (var r = 0; r < rows; r++) ...[
        if (r > 0) SizedBox(height: gap),
        Expanded(
          child: Row(children: [
            for (var c = 0; c < cols; c++) ...[
              if (c > 0) SizedBox(width: gap),
              Expanded(child: r * cols + c < n ? cell(r * cols + c) : const SizedBox()),
            ],
          ]),
        ),
      ],
    ]);
  }

  Widget _tile({required Color color, required VoidCallback onTap, required Widget child}) => Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Center(child: child)),
      );
}

/// Les gobelets : la balle se montre, les gobelets se mélangent, puis on touche le bon
class MngCups extends StatefulWidget {
  const MngCups({super.key, required this.q, required this.onPick});
  final Map<String, dynamic> q;
  final ValueChanged<int> onPick;

  @override
  State<MngCups> createState() => _MngCupsState();
}

class _MngCupsState extends State<MngCups> {
  late final int n = (widget.q['n'] as num).toInt();
  late List<int> slot = List.generate(n, (i) => i); // slot[gobelet] = place
  bool lifted = true;
  bool ball = true; // la balle n'est visible que gobelet levé
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final ms = (widget.q['swapMs'] as num?)?.toInt() ?? 500;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => lifted = false);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => ball = false); // le gobelet est posé : plus de balle visible
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (final s in widget.q['swaps'] as List) {
      final a = (s[0] as num).toInt(), b = (s[1] as num).toInt();
      if (!mounted) return;
      // échange les gobelets qui sont aux places a et b
      final ca = slot.indexOf(a), cb = slot.indexOf(b);
      setState(() {
        slot[ca] = b;
        slot[cb] = a;
      });
      await Future<void>.delayed(Duration(milliseconds: ms + 60));
    }
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final start = (widget.q['start'] as num).toInt();
    final ms = (widget.q['swapMs'] as num?)?.toInt() ?? 500;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / n;
      return Stack(children: [
        Positioned(left: 0, right: 0, bottom: 10, child: Text(ready ? 'Touche le bon gobelet !' : 'Suis la balle…', textAlign: TextAlign.center, style: Pb.t(18, color: Pb.muted))),
        for (var cup = 0; cup < n; cup++)
          AnimatedPositioned(
            key: ValueKey(cup),
            duration: Duration(milliseconds: ms),
            curve: Curves.easeInOut,
            left: slot[cup] * w,
            top: c.maxHeight * .2,
            width: w,
            height: c.maxHeight * .55,
            child: GestureDetector(
              onTap: ready ? () => widget.onPick(slot[cup]) : null,
              child: Stack(alignment: Alignment.bottomCenter, children: [
                if (cup == start && ball) const Positioned(bottom: 0, child: Text('🔴', style: TextStyle(fontSize: 30))),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  offset: Offset(0, lifted && cup == start ? -.45 : 0),
                  child: const FittedBox(child: Text('🥤', style: TextStyle(fontSize: 90))),
                ),
              ]),
            ),
          ),
      ]);
    });
  }
}

/// Les dessins des questions (et de l'étape « à retenir »)
class MngPic extends StatelessWidget {
  const MngPic({super.key, required this.pic});
  final Map<String, dynamic> pic;

  List<String?> _items(String k) => [for (final x in (pic[k] as List? ?? const [])) x is String ? (x.isEmpty ? null : x) : null];

  @override
  Widget build(BuildContext context) {
    switch (pic['type']) {
      case 'big':
        return FittedBox(child: Text(pic['e'] as String? ?? '', style: const TextStyle(fontSize: 120)));
      case 'text':
        final t = pic['t'] as String? ?? '';
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(t, textAlign: TextAlign.center, style: Pb.t(pic['big'] == true ? 52 : 44, weight: 700).copyWith(letterSpacing: pic['spaced'] == true ? 8 : null)),
        );
      case 'mirror':
        final e = pic['e'] as String? ?? '';
        return FittedBox(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(e, style: const TextStyle(fontSize: 90)),
            Container(width: 6, height: 110, margin: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Pb.cyan, borderRadius: BorderRadius.circular(3))),
            Text('❓', style: Pb.t(70)),
          ]),
        );
      case 'stroop':
        return FittedBox(child: Text(pic['w'] as String? ?? '', style: Pb.t(80, weight: 700, color: Color((pic['c'] as num).toInt()))));
      case 'lines':
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final l in (pic['lines'] as List? ?? const [])) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('$l', style: Pb.t(40, weight: 700))),
          ]),
        );
      case 'pair':
        Widget box(String s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(16)),
              child: Text(s, style: Pb.t(44, weight: 700)),
            );
        return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [box('${pic['a']}'), const SizedBox(width: 18), box('${pic['b']}')]));
      case 'grid':
        return _gridPic(_items('items'), (pic['cols'] as num?)?.toInt() ?? 3, small: pic['small'] == true);
      case 'two':
        return Row(children: [
          Expanded(child: _gridPic(_items('a'), 3)),
          Container(width: 3, margin: const EdgeInsets.symmetric(horizontal: 8), color: Pb.cyan),
          Expanded(child: _gridPic(_items('b'), 3)),
        ]);
      case 'clock':
        return AspectRatio(aspectRatio: 1, child: CustomPaint(painter: _ClockPainter((pic['h'] as num).toInt(), (pic['m'] as num).toInt())));
      case 'cubes':
        return AspectRatio(aspectRatio: 1.5, child: CustomPaint(painter: _CubesPainter([for (final c in pic['cubes'] as List) [for (final v in c as List) (v as num).toInt()]])));
      case 'dots':
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(18)),
            child: LayoutBuilder(builder: (context, c) => Stack(children: [
                  for (final p in pic['pts'] as List)
                    Positioned(
                      left: (p[0] as num) / 100 * c.maxWidth - 9,
                      top: (p[1] as num) / 100 * c.maxHeight - 9,
                      child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Pb.yellow, shape: BoxShape.circle)),
                    ),
                ])),
          ),
        );
      case 'reveal':
        return _Reveal(emoji: pic['e'] as String? ?? '', ms: (pic['ms'] as num?)?.toInt() ?? 4000);
      case 'steps':
        return _Steps(items: [for (final x in pic['items'] as List) '$x'], ms: (pic['ms'] as num?)?.toInt() ?? 900, text: pic['text'] == true);
      case 'dice':
        return FittedBox(
          child: Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
            for (final v in pic['d'] as List)
              SizedBox(width: 110, height: 110, child: CustomPaint(painter: _PipsPainter([(v as num).toInt()], die: true))),
          ]),
        );
      case 'domino':
        return FittedBox(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final d in pic['d'] as List)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(width: 110, height: 220, child: CustomPaint(painter: _PipsPainter([for (final v in d as List) (v as num).toInt()]))),
              ),
          ]),
        );
      case 'tri':
        return AspectRatio(aspectRatio: 1.15, child: CustomPaint(painter: _TriPainter((pic['n'] as num).toInt(), pic['h'] == true)));
      case 'net':
        final cells = [for (final c in pic['cells'] as List) [for (final v in c as List) (v as num).toInt()]];
        final faces = [for (final f in pic['faces'] as List) '$f'];
        final w = cells.map((c) => c[0]).reduce(math.max) + 1;
        final h = cells.map((c) => c[1]).reduce(math.max) + 1;
        return AspectRatio(
          aspectRatio: w / h,
          child: LayoutBuilder(builder: (context, c) {
            final s = c.maxWidth / w;
            return Stack(children: [
              for (var i = 0; i < cells.length; i++)
                Positioned(
                  left: cells[i][0] * s,
                  top: cells[i][1] * s,
                  width: s,
                  height: s,
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(color: const Color(0xFFF7F2FF), border: Border.all(color: Pb.bg, width: 2)),
                    child: FittedBox(child: Padding(padding: const EdgeInsets.all(6), child: Text(faces[i], style: const TextStyle(fontSize: 40)))),
                  ),
                ),
            ]);
          }),
        );
    }
    return const SizedBox.shrink();
  }

  Widget _gridPic(List<String?> items, int cols, {bool small = false}) {
    final rows = (items.length / cols).ceil();
    return AspectRatio(
      aspectRatio: cols / rows,
      child: Column(children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Row(children: [
              for (var c = 0; c < cols; c++)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(small ? 1.5 : 4),
                    decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(small ? 4 : 12)),
                    child: r * cols + c < items.length && items[r * cols + c] != null
                        ? FittedBox(child: Padding(padding: const EdgeInsets.all(4), child: Text(items[r * cols + c]!, style: const TextStyle(fontSize: 40))))
                        : null,
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// Un dessin qui se dévoile : un rond qui grandit
class _Reveal extends StatefulWidget {
  const _Reveal({required this.emoji, required this.ms});
  final String emoji;
  final int ms;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.ms))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(18)),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) => ClipPath(clipper: _CircleClip(.12 + _c.value * .9), child: child),
            child: FittedBox(child: Padding(padding: const EdgeInsets.all(14), child: Text(widget.emoji, style: const TextStyle(fontSize: 120)))),
          ),
        ),
      );
}

class _CircleClip extends CustomClipper<Path> {
  _CircleClip(this.f);
  final double f;
  @override
  Path getClip(Size s) => Path()..addOval(Rect.fromCircle(center: Offset(s.width * .5, s.height * .42), radius: s.width * .5 * f));
  @override
  bool shouldReclip(_CircleClip o) => o.f != f;
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.h, this.m);
  final int h, m;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF7F2FF));
    canvas.drawCircle(c, r, Paint()
      ..color = Pb.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .07);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final p1 = c + Offset(math.sin(a), -math.cos(a)) * r * .82;
      final p2 = c + Offset(math.sin(a), -math.cos(a)) * r * (i % 3 == 0 ? .66 : .74);
      canvas.drawLine(p1, p2, Paint()
        ..color = Pb.bg
        ..strokeWidth = i % 3 == 0 ? r * .05 : r * .025
        ..strokeCap = StrokeCap.round);
    }
    final am = m / 60 * 2 * math.pi;
    final ah = ((h % 12) + m / 60) / 12 * 2 * math.pi;
    canvas.drawLine(c, c + Offset(math.sin(ah), -math.cos(ah)) * r * .48, Paint()
      ..color = Pb.bg
      ..strokeWidth = r * .09
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(c, c + Offset(math.sin(am), -math.cos(am)) * r * .74, Paint()
      ..color = const Color(0xFF3F8CFF)
      ..strokeWidth = r * .055
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, r * .06, Paint()..color = Pb.pink);
  }

  @override
  bool shouldRepaint(_ClockPainter o) => o.h != h || o.m != m;
}

/// Cubes empilés en perspective (x : colonne, y : rangée vers le fond, z : hauteur)
class _CubesPainter extends CustomPainter {
  _CubesPainter(this.cubes);
  final List<List<int>> cubes;

  // repère « unité » : x vers la droite-bas, y vers la droite-haut (le fond), z vers le haut
  static Offset _p(num x, num y, num z) => Offset((x + y) * .87, (x - y) * .5 - z);

  @override
  void paint(Canvas canvas, Size s) {
    if (cubes.isEmpty) return;
    // cadre de tous les coins, pour tout faire tenir au centre
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final c in cubes) {
      for (final d in const [[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0], [0, 0, 1], [1, 0, 1], [0, 1, 1], [1, 1, 1]]) {
        final o = _p(c[0] + d[0], c[1] + d[1], c[2] + d[2]);
        minX = math.min(minX, o.dx); maxX = math.max(maxX, o.dx);
        minY = math.min(minY, o.dy); maxY = math.max(maxY, o.dy);
      }
    }
    final k = math.min((s.width - 8) / (maxX - minX), (s.height - 8) / (maxY - minY));
    final off = Offset((s.width - (maxX - minX) * k) / 2 - minX * k, (s.height - (maxY - minY) * k) / 2 - minY * k);
    Offset at(num x, num y, num z) => _p(x, y, z) * k + off;
    final edge = Paint()
      ..color = Pb.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    // du plus loin (x − y petit) au plus près, du bas vers le haut
    final order = [...cubes]..sort((a, b) {
        final da = a[0] - a[1], db = b[0] - b[1];
        if (da != db) return da - db;
        return a[2] - b[2];
      });
    Path face(List<Offset> pts) => Path()..addPolygon(pts, true);
    for (final c in order) {
      final x = c[0], y = c[1], z = c[2];
      final top = face([at(x, y, z + 1), at(x + 1, y, z + 1), at(x + 1, y + 1, z + 1), at(x, y + 1, z + 1)]);
      final front = face([at(x, y, z), at(x + 1, y, z), at(x + 1, y, z + 1), at(x, y, z + 1)]);
      final side = face([at(x + 1, y, z), at(x + 1, y + 1, z), at(x + 1, y + 1, z + 1), at(x + 1, y, z + 1)]);
      canvas.drawPath(top, Paint()..color = const Color(0xFFFFD23F));
      canvas.drawPath(front, Paint()..color = const Color(0xFFFF9A1F));
      canvas.drawPath(side, Paint()..color = const Color(0xFFE06A00));
      for (final p in [top, front, side]) {
        canvas.drawPath(p, edge);
      }
    }
  }

  @override
  bool shouldRepaint(_CubesPainter o) => o.cubes != cubes;
}


/// Des choses qui passent une par une (ordre d'apparition, calcul en chaîne)
class _Steps extends StatefulWidget {
  const _Steps({required this.items, required this.ms, required this.text});
  final List<String> items;
  final int ms;
  final bool text;

  @override
  State<_Steps> createState() => _StepsState();
}

class _StepsState extends State<_Steps> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(Duration(milliseconds: widget.ms), (_) {
      if (_i >= widget.items.length - 1) {
        _t?.cancel();
        setState(() => _i = widget.items.length); // tout est passé
      } else {
        setState(() => _i++);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _i < widget.items.length ? widget.items[_i] : '';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${math.min(_i + 1, widget.items.length)} / ${widget.items.length}', style: Pb.t(18, color: Pb.muted)),
      const SizedBox(height: 10),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Container(
          key: ValueKey(_i),
          width: 220,
          height: 170,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: s.isEmpty ? Colors.transparent : Pb.card, borderRadius: BorderRadius.circular(24)),
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(s, style: widget.text ? Pb.t(70, weight: 700) : const TextStyle(fontSize: 100)),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Points d'un dé (une valeur) ou d'un domino (deux valeurs l'une sur l'autre)
class _PipsPainter extends CustomPainter {
  _PipsPainter(this.values, {this.die = false});
  final List<int> values;
  final bool die;

  static const _spots = <int, List<List<double>>>{
    0: [],
    1: [[.5, .5]],
    2: [[.25, .25], [.75, .75]],
    3: [[.25, .25], [.5, .5], [.75, .75]],
    4: [[.25, .25], [.75, .25], [.25, .75], [.75, .75]],
    5: [[.25, .25], [.75, .25], [.5, .5], [.25, .75], [.75, .75]],
    6: [[.25, .22], [.75, .22], [.25, .5], [.75, .5], [.25, .78], [.75, .78]],
  };

  @override
  void paint(Canvas canvas, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.width * .16));
    canvas.drawRRect(r, Paint()..color = const Color(0xFFF7F2FF));
    canvas.drawRRect(r, Paint()
      ..color = Pb.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    final cell = s.height / values.length;
    for (var k = 0; k < values.length; k++) {
      if (k > 0) canvas.drawLine(Offset(s.width * .1, cell * k), Offset(s.width * .9, cell * k), Paint()..color = Pb.bg..strokeWidth = 3);
      for (final p in _spots[values[k].clamp(0, 6)]!) {
        canvas.drawCircle(Offset(p[0] * s.width, cell * k + p[1] * cell), s.width * .09, Paint()..color = die ? const Color(0xFFE5484D) : Pb.bg);
      }
    }
  }

  @override
  bool shouldRepaint(_PipsPainter o) => o.values.join() != values.join();
}

/// Un grand triangle coupé par des traits depuis le sommet (et parfois un trait horizontal)
class _TriPainter extends CustomPainter {
  _TriPainter(this.n, this.h);
  final int n;
  final bool h;

  @override
  void paint(Canvas canvas, Size s) {
    final top = Offset(s.width / 2, s.height * .05);
    final l = Offset(s.width * .04, s.height * .95), r = Offset(s.width * .96, s.height * .95);
    final p = Paint()
      ..color = Pb.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(Path()..addPolygon([top, l, r], true), p);
    for (var k = 1; k <= n; k++) {
      canvas.drawLine(top, Offset.lerp(l, r, k / (n + 1))!, p);
    }
    if (h) {
      const f = .58;
      canvas.drawLine(Offset.lerp(top, l, f)!, Offset.lerp(top, r, f)!, p);
    }
  }

  @override
  bool shouldRepaint(_TriPainter o) => o.n != n || o.h != h;
}
