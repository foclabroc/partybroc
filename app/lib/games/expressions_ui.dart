import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// L'expression en grand : le mot caché est une case vide pendant la question,
/// puis le mot en jaune à la révélation.
class ExpText extends StatelessWidget {
  const ExpText({super.key, required this.text, this.answer, required this.size, this.align = TextAlign.center});
  final String text; // avec ___ à la place du mot caché
  final String? answer; // donné à la révélation
  final double size;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('___');
    final base = Pb.t(size, weight: 700, height: 1.25);
    final hole = answer == null
        ? WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: size * 3.2,
              height: size * 1.05,
              margin: EdgeInsets.symmetric(horizontal: size * .12),
              decoration: BoxDecoration(
                color: Pb.yellow.withValues(alpha: .18),
                border: Border(bottom: BorderSide(color: Pb.yellow, width: size * .08)),
                borderRadius: BorderRadius.circular(size * .15),
              ),
              alignment: Alignment.center,
              child: Text('?', style: Pb.t(size * .8, weight: 700, color: Pb.yellow)),
            ),
          )
        : TextSpan(text: answer, style: base.copyWith(color: Pb.yellow));
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: parts.first),
        if (parts.length > 1) ...[hole, TextSpan(text: parts.sublist(1).join('___'))],
      ]),
      textAlign: align,
    );
  }
}

/// Expressions à trous sur la TV
class ExpTv extends StatelessWidget {
  const ExpTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🗣️',
          title: 'Expressions à trous',
          sub: '${live.i('count')} expressions',
          rules: const [
            'Une expression s’affiche avec un mot caché : trouve lequel !',
            'De temps en temps, c’est l’inverse : que veut dire l’expression ?',
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
    final sens = live.s('kind') == 'sens';
    final picks = {for (final e in ((live['picks'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()};
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(
          label: 'Expression',
          index: live.i('index'),
          count: live.i('count'),
          live: reveal ? null : live,
          extra: TvChip(text: sens ? '🤔 Que veut dire…' : '🔎 Le mot qui manque', color: Pb.yellow, size: 34),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 1700,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (sens)
                    Text('« ${live.s('text') ?? ''} »', textAlign: TextAlign.center, style: Pb.t(reveal ? 66 : 84, weight: 700, height: 1.2))
                  else
                    ExpText(text: live.s('text') ?? '', answer: reveal ? live.s('answer') : null, size: reveal ? 74 : 88),
                  // À la révélation : ce que veut dire l'expression
                  if (reveal && !sens && (live.s('meaning') ?? '').isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('= ${live.s('meaning')}', textAlign: TextAlign.center, style: Pb.t(44, color: Pb.muted, height: 1.2)),
                  ],
                ]),
              ),
            ),
          ),
        ),
        TvChoices(
          room: room,
          choices: live.pids('choices'),
          kind: sens ? 'long' : 'text',
          cols: sens ? 1 : 2,
          correct: reveal ? live.i('correct') : null,
          picks: picks,
          height: sens ? 92 : 120,
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 90,
          child: reveal ? TvGains(room: room, ranking: live.ranking) : TvWhoDone(room: room, done: live.pids('answered').toSet()),
        ),
      ]),
    );
  }
}

/// Expressions à trous sur le téléphone
class ExpPlay extends StatelessWidget {
  const ExpPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final sens = live.s('kind') == 'sens';
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🗣️', title: 'Expressions à trous', sub: 'Trouve le mot qui manque dans l’expression. Un seul essai !'),
      'ask' => Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
            const SizedBox(height: 12),
            // L'expression aussi sur le téléphone, pour qui voit mal la TV
            if (sens) ...[
              Text('Que veut dire…', textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: Pb.yellow)),
              const SizedBox(height: 4),
              Text('« ${live.s('text') ?? ''} »', textAlign: TextAlign.center, style: Pb.t(21, weight: 700, height: 1.2)),
            ] else
              ExpText(text: live.s('text') ?? '', size: 22),
            const SizedBox(height: 14),
            Expanded(
              child: PhoneChoices(
                choices: live.pids('choices'),
                kind: sens ? 'long' : 'text',
                picked: you.yi('answer'),
                onPick: (i) => send({'t': 'game_msg', 'm': {'t': 'exp_pick', 'r': live.i('index'), 'choice': i}}),
              ),
            ),
          ]),
        ),
      'reveal' => phoneGain(you, good: 'Bien trouvé ! 🗣️', none: 'Raté !'),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }
}
