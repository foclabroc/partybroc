import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// Les emojis du rébus, en très grand (ils rétrécissent si la suite est longue)
class RbsEmojis extends StatelessWidget {
  const RbsEmojis({super.key, required this.emojis, this.size = 230});
  final String emojis;
  final double size;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .4, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Text(emojis, style: TextStyle(fontSize: size, height: 1.15, letterSpacing: size * .08)),
        ),
      );
}

/// Emoji rébus sur la TV
class RbsTv extends StatelessWidget {
  const RbsTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🧐',
          title: 'Emoji rébus',
          sub: '${live.i('count')} rébus',
          rules: const [
            'Des emojis s’affichent : film, expression, métier, pays…',
            'Choisis la bonne réponse sur ton téléphone. Plus tu es rapide, plus tu marques !',
          ],
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
    final hint = live.s('hint') ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(
          label: 'Rébus',
          index: live.i('index'),
          count: live.i('count'),
          live: reveal ? null : live,
          extra: TvChip(text: live.s('category') ?? '', color: Pb.yellow, size: 36),
        ),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            RbsEmojis(emojis: live.s('emojis') ?? '', size: reveal ? 170 : 230),
            if (reveal && hint.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(hint, textAlign: TextAlign.center, style: Pb.t(38, color: Pb.muted)),
            ],
          ]),
        ),
        TvChoices(room: room, choices: live.pids('choices'), correct: reveal ? live.i('correct') : null, picks: picks, height: 120),
        const SizedBox(height: 22),
        SizedBox(
          height: 90,
          child: reveal ? TvGains(room: room, ranking: live.ranking) : TvWhoDone(room: room, done: live.pids('answered').toSet()),
        ),
      ]),
    );
  }
}

/// Emoji rébus sur le téléphone
class RbsPlay extends StatelessWidget {
  const RbsPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🧐', title: 'Emoji rébus', sub: 'Regarde les emojis sur la TV et trouve ce qu’ils veulent dire. Un seul essai !'),
      'ask' => Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
            const SizedBox(height: 12),
            // Les emojis aussi sur le téléphone, pour qui voit mal la TV
            SizedBox(height: 70, child: RbsEmojis(emojis: live.s('emojis') ?? '', size: 56)),
            Text(live.s('category') ?? '', textAlign: TextAlign.center, style: Pb.t(18, weight: 600, color: Pb.yellow)),
            const SizedBox(height: 12),
            Expanded(
              child: PhoneChoices(
                choices: live.pids('choices'),
                picked: you.yi('answer'),
                onPick: (i) => send({'t': 'game_msg', 'm': {'t': 'rbs_pick', 'r': live.i('index'), 'choice': i}}),
              ),
            ),
          ]),
        ),
      'reveal' => phoneGain(you, good: 'Bien trouvé ! 🧐', none: 'Raté !'),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }
}
