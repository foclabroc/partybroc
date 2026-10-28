import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// Le dernier debout sur la TV
class SurvTv extends StatelessWidget {
  const SurvTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🏁',
          title: 'Le dernier debout',
          sub: 'Vrai ou faux ?',
          rules: const ['Une erreur (ou pas de réponse) et tu es éliminé !', 'Si tous les survivants se trompent, personne ne sort. Le dernier debout gagne.'],
          live: live),
      'ask' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'reveal' ? 'ask' : ph}-${live.i('index')}', child: body);
  }

  Widget _round() {
    final reveal = live.phase == 'reveal';
    final alive = live.pids('alive');
    final out = live.pids('out');
    final winners = live.pids('winners');
    final truth = live['truth'] == true;
    final everyone = room.players.where((p) => p.connected || alive.contains(p.pid)).map((p) => p.pid).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(
          label: 'Question',
          index: live.i('index'),
          count: live.i('count'),
          live: reveal ? null : live,
          extra: TvChip(text: '${alive.length} en course', color: Pb.yellow, size: 34),
        ),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(live.s('statement') ?? '', textAlign: TextAlign.center, style: Pb.t(reveal ? 62 : 80, weight: 700, height: 1.15)),
            const SizedBox(height: 40),
            if (!reveal)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TvChip(text: '✅ VRAI', bg: Pb.green, color: Pb.bg, size: 64),
                const SizedBox(width: 60),
                TvChip(text: '❌ FAUX', bg: Pb.red, size: 64),
              ])
            else ...[
              TvChip(text: truth ? '✅ VRAI' : '❌ FAUX', bg: truth ? Pb.green : Pb.red, color: truth ? Pb.bg : Pb.text, size: 80),
              const SizedBox(height: 20),
              if ((live.s('explain') ?? '').isNotEmpty) Text(live.s('explain')!, textAlign: TextAlign.center, style: Pb.t(40, color: Pb.muted)),
              const SizedBox(height: 26),
              if (winners.isNotEmpty)
                Text(winners.length == 1 ? '🏆 ${room.player(winners.first)?.name ?? '?'} est le dernier debout !' : '🏆 ${winners.length} survivants jusqu’au bout !',
                    style: Pb.t(60, weight: 700, color: Pb.yellow))
              else if (live['saved'] == true)
                Text('Tout le monde s’est trompé : personne ne sort ! 😅', style: Pb.t(48, weight: 700, color: Pb.yellow))
              else if (out.isNotEmpty)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Éliminé${out.length > 1 ? 's' : ''} : ', style: Pb.t(44, weight: 700, color: Pb.red)),
                  TvAvatarRow(room: room, pids: out, size: 76, badge: '💀'),
                ])
              else
                Text('Personne n’est éliminé 💪', style: Pb.t(48, weight: 700, color: Pb.green)),
            ],
          ]),
        ),
        if (!reveal) ...[TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16), const SizedBox(height: 24)],
        // Tous les joueurs : les éliminés en grisé
        SizedBox(height: 96, child: Center(child: TvAvatarRow(room: room, pids: everyone, dim: everyone.where((p) => !alive.contains(p)).toSet()))),
      ]),
    );
  }
}

/// Le dernier debout sur le téléphone
class SurvPlay extends StatelessWidget {
  const SurvPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🏁', title: 'Le dernier debout', sub: 'Vrai ou faux ? Une erreur et tu es éliminé !'),
      'ask' => _ask(),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _ask() {
    final alive = you.yb('alive');
    final answer = you?['answer'] as bool?;
    Widget btn(bool v) {
      final c = v ? Pb.green : Pb.red;
      return Expanded(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: answer != null && answer != v ? .25 : 1,
          child: Material(
            color: c,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: answer != null
                  ? null
                  : () {
                      HapticFeedback.heavyImpact();
                      send({'t': 'game_msg', 'm': {'t': 'surv_answer', 'r': live.i('index'), 'v': v}});
                    },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: answer == v ? Border.all(color: Colors.white, width: 4) : null),
                child: Text(v ? '✅ VRAI' : '❌ FAUX', style: Pb.t(40, weight: 700, color: v ? Pb.bg : Colors.white)),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
        const SizedBox(height: 10),
        Text(alive ? '💪 Tu es encore en course' : '👻 Éliminé : tu joues pour le plaisir', textAlign: TextAlign.center,
            style: Pb.t(15, weight: 600, color: alive ? Pb.green : Pb.muted)),
        const SizedBox(height: 10),
        Text(live.s('statement') ?? '', textAlign: TextAlign.center, style: Pb.t(23, weight: 700, height: 1.2)),
        const SizedBox(height: 16),
        btn(true),
        const SizedBox(height: 12),
        btn(false),
      ]),
    );
  }

  Widget _reveal() {
    final truth = live['truth'] == true;
    final good = (you?['answer'] as bool?) == truth;
    final alive = you.yb('alive');
    final won = alive && live.pids('winners').isNotEmpty;
    final (emoji, title) = switch ((alive, you.yb('outNow'))) {
      (true, _) => won ? ('🏆', 'Tu es le dernier debout !') : (good ? ('💪', 'Bonne réponse, tu restes !') : ('😅', 'Tout le monde s’est trompé : tu restes !')),
      (false, true) => ('💀', 'Éliminé !'),
      _ => good ? ('👍', 'Bonne réponse') : ('🙃', 'C’était ${truth ? 'VRAI' : 'FAUX'}'),
    };
    return PhoneCenter(
      emoji: emoji,
      title: title,
      color: alive ? Pb.green : Pb.text,
      extra: Text(live.s('explain') ?? '', textAlign: TextAlign.center, style: Pb.t(17, color: Pb.muted)),
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}
