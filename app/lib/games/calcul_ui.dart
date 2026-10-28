import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// Course de calcul sur la TV
class CalcTv extends StatelessWidget {
  const CalcTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '➗',
          title: 'Course de calcul',
          sub: '${live.i('count')} calculs · niveau ${live.s('level') ?? ''}'.trim(),
          rules: const ['Tape le résultat sur ton téléphone.', 'Juste et rapide = plus de points. Le premier gagne un bonus !'],
          live: live),
      'ask' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'reveal' ? 'ask' : ph}-${live.i('index')}', child: body);
  }

  Widget _round() {
    final reveal = live.phase == 'reveal';
    final good = live.maps('good');
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 50, 80, 50),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Calcul', index: live.i('index'), count: live.i('count'), live: reveal ? null : live),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: live.s('expr') ?? '', style: Pb.t(190, weight: 700)),
                  if (reveal) TextSpan(text: '  =  ${fmtNum(live.i('value'))}', style: Pb.t(190, weight: 700, color: Pb.yellow)),
                ])),
              ),
              if (reveal) ...[
                const SizedBox(height: 30),
                if (good.isEmpty)
                  Text('Personne n’a trouvé 😅', style: Pb.t(50, weight: 600, color: Pb.muted))
                else
                  Wrap(spacing: 36, runSpacing: 16, alignment: WrapAlignment.center, children: [
                    for (final (i, g) in good.take(8).indexed)
                      if (room.player(g['pid'] as String) case final p?)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          if (i == 0) const Text('⚡', style: TextStyle(fontSize: 50)),
                          PbAvatar(size: i == 0 ? 96 : 72, emoji: p.emoji, color: p.color, photoPath: p.photo),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(p.name, style: Pb.t(i == 0 ? 40 : 32, weight: 700)),
                            Text('${((g['ms'] as num) / 1000).toStringAsFixed(1).replaceAll('.', ',')} s', style: Pb.t(30, color: Pb.cyan)),
                          ]),
                        ]),
                  ]),
              ],
            ]),
          ),
        ),
        if (!reveal) ...[
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
          const SizedBox(height: 30),
          SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('answered').toSet())),
        ] else
          SizedBox(height: 90, child: TvGains(room: room, ranking: live.ranking)),
      ]),
    );
  }
}

/// Course de calcul sur le téléphone
class CalcPlay extends StatelessWidget {
  const CalcPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '➗', title: 'Course de calcul', sub: 'Tape le résultat le plus vite possible !'),
      'ask' => _ask(),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _ask() {
    final sent = you?['answer'] as num?;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 44, 18, 18), children: [
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 30),
      FittedBox(child: Text('${live.s('expr') ?? ''} = ?', style: Pb.t(54, weight: 700))),
      const SizedBox(height: 30),
      PhoneNumberInput(
        key: ValueKey('calc-${live.i('index')}'),
        sent: sent,
        onSubmit: (v) => send({'t': 'game_msg', 'm': {'t': 'calc_answer', 'r': live.i('index'), 'v': v.toInt()}}),
      ),
    ]);
  }

  Widget _reveal() {
    final g = you.yi('gain') ?? 0;
    final mine = you?['answer'] as num?;
    return PhoneCenter(
      emoji: g > 0 ? '🎯' : (mine == null ? '⏰' : '❌'),
      title: '${live.s('expr')} = ${fmtNum(live.i('value'))}',
      color: g > 0 ? Pb.green : Pb.text,
      extra: g > 0
          ? Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green))
          : Text(mine == null ? 'Pas de réponse' : 'Tu as répondu ${fmtNum(mine)}', style: Pb.t(20, color: Pb.muted)),
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}
