import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// La grille de Mémoire : emojis sur des cases de couleur
class MemGrid extends StatelessWidget {
  const MemGrid({super.key, required this.cells, required this.cols, this.cell = 220});
  final List<Map<String, dynamic>> cells;
  final int cols;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final rows = (cells.length / cols).ceil();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var r = 0; r < rows; r++)
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var c = 0; c < cols && r * cols + c < cells.length; c++)
            Container(
              width: cell,
              height: cell,
              margin: EdgeInsets.all(cell * .05),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: memColors[cells[r * cols + c]['c']] ?? Pb.card,
                borderRadius: BorderRadius.circular(cell * .16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: cell * .08, offset: Offset(0, cell * .03))],
              ),
              child: Text(cells[r * cols + c]['e'] as String, style: TextStyle(fontSize: cell * .58, height: 1.1)),
            ),
        ]),
    ]);
  }
}

/// Mémoire sur la TV
class MemTv extends StatelessWidget {
  const MemTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🧩',
          title: 'Mémoire',
          sub: '${live.i('count')} images',
          rules: const ['Une image s’affiche 10 secondes : retiens tout !', 'Puis elle disparaît et une question arrive. Réponds vite sur ton téléphone.'],
          live: live),
      'show' => _show(),
      'ask' || 'reveal' => _ask(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'reveal' ? 'ask' : ph}-${live.i('index')}', child: body);
  }

  Widget _show() => Padding(
        padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
        child: Column(children: [
          TvHeader(label: 'Image', index: live.i('index'), count: live.i('count'), live: live, extra: Text('👀 Mémorise !', style: Pb.t(50, weight: 700, color: Pb.yellow))),
          Expanded(child: Center(child: MemGrid(cells: live.maps('cells'), cols: live.i('cols', 4), cell: 250))),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
        ]),
      );

  Widget _ask() {
    final reveal = live.phase == 'reveal';
    final picks = {for (final e in ((live['picks'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()};
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Image', index: live.i('index'), count: live.i('count'), live: reveal ? null : live),
        const SizedBox(height: 20),
        Expanded(
          child: Row(children: [
            if (reveal) ...[
              MemGrid(cells: live.maps('cells'), cols: live.i('cols', 4), cell: 150),
              const SizedBox(width: 50),
            ],
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(live.s('question') ?? '', textAlign: TextAlign.center, style: Pb.t(reveal ? 60 : 76, weight: 700, height: 1.15)),
                const SizedBox(height: 40),
                TvChoices(
                  room: room,
                  choices: live.pids('choices'),
                  kind: live.s('kind') ?? 'text',
                  correct: reveal ? live.i('correct') : null,
                  picks: picks,
                  height: reveal ? 130 : 150,
                ),
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

/// Mémoire sur le téléphone
class MemPlay extends StatelessWidget {
  const MemPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🧩', title: 'Mémoire', sub: 'Regarde bien la TV : l’image va disparaître !'),
      'show' => const PhoneCenter(emoji: '👀', title: 'Regarde la TV !', sub: 'Retiens les emojis, leur nombre, leurs couleurs et leur place.'),
      'ask' => _ask(),
      'reveal' => phoneGain(you, good: 'Quelle mémoire !', none: 'Raté !'),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _ask() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
          const SizedBox(height: 14),
          Text(live.s('question') ?? '', textAlign: TextAlign.center, style: Pb.t(22, weight: 700, height: 1.2)),
          const SizedBox(height: 14),
          Expanded(
            child: PhoneChoices(
              choices: live.pids('choices'),
              kind: live.s('kind') ?? 'text',
              picked: you.yi('answer'),
              onPick: (i) => send({'t': 'game_msg', 'm': {'t': 'mem_pick', 'r': live.i('index'), 'choice': i}}),
            ),
          ),
        ]),
      );
}
