import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// Le juste prix sur la TV
class JpTv extends StatelessWidget {
  const JpTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '💶',
          title: 'Le juste prix',
          sub: '${live.i('count')} objets',
          rules: const ['Tape le prix sur ton téléphone (prix moyens en France).', 'Le plus proche gagne. À moins de 2 % : c’est le juste prix !'],
          live: live),
      'ask' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '$ph-${live.i('index')}', child: body);
  }

  Widget _item({bool small = false}) => Column(mainAxisSize: MainAxisSize.min, children: [
        PbPhoto(id: live.s('img'), emoji: live.s('emoji') ?? '🛒', size: small ? 220 : 380),
        const SizedBox(height: 16),
        Text(live.s('name') ?? '', textAlign: TextAlign.center, style: Pb.t(small ? 54 : 76, weight: 700, height: 1.1)),
        Text(live.s('detail') ?? '', textAlign: TextAlign.center, style: Pb.t(small ? 32 : 42, color: Pb.muted)),
      ]);

  Widget _round() {
    final reveal = live.phase == 'reveal';
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Objet', index: live.i('index'), count: live.i('count'), live: reveal ? null : live),
        Expanded(
          child: reveal
              ? Row(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _item(small: true),
                      const SizedBox(height: 30),
                      Text('Prix moyen', style: Pb.t(36, color: Pb.muted)),
                      Text(euros(live['price'] as num? ?? 0), style: Pb.t(110, weight: 700, color: Pb.yellow)),
                    ]),
                  ),
                  const SizedBox(width: 40),
                  Expanded(child: _guesses()),
                ])
              : Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _item(),
                    const SizedBox(height: 30),
                    Text('Combien ça coûte ?', style: Pb.t(56, weight: 700, color: Pb.yellow)),
                  ]),
                ),
        ),
        if (!reveal) ...[
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
          const SizedBox(height: 24),
          SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('answered').toSet())),
        ],
      ]),
    );
  }

  // Les propositions, de la plus proche à la plus loin
  Widget _guesses() {
    final list = live.maps('guesses');
    if (list.isEmpty) return Center(child: Text('Personne n’a proposé de prix 🤷', style: Pb.t(44, color: Pb.muted)));
    final gains = {for (final r in live.ranking) r.pid: r.gain};
    final many = list.length > 8;
    return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final g in list.take(many ? 12 : 8))
        if (room.player(g['pid'] as String) case final p?)
          Container(
            margin: EdgeInsets.only(bottom: many ? 6 : 12),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: many ? 4 : 10),
            decoration: BoxDecoration(
              color: g['rank'] == 0 ? Pb.cardHi : Pb.card.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(24),
              border: g['rank'] == 0 ? Border.all(color: Pb.yellow, width: 3) : null,
            ),
            child: Row(children: [
              Text(g['rank'] == 0 ? '🥇' : '${(g['rank'] as int) + 1}.', style: Pb.t(many ? 28 : 36, weight: 700, color: Pb.muted)),
              const SizedBox(width: 14),
              PbAvatar(size: many ? 44 : 60, emoji: p.emoji, color: p.color, photoPath: p.photo),
              const SizedBox(width: 14),
              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(many ? 28 : 36, weight: 600))),
              if (g['exact'] == true) Text('🎯 ', style: TextStyle(fontSize: many ? 28 : 36)),
              Text(euros(g['v'] as num), style: Pb.t(many ? 30 : 40, weight: 700)),
              SizedBox(
                width: 130,
                child: Text((gains[p.pid] ?? 0) > 0 ? '+${Pb.pts(gains[p.pid]!)}' : '',
                    textAlign: TextAlign.right, style: Pb.t(many ? 28 : 34, weight: 700, color: Pb.green)),
              ),
            ]),
          ),
    ]);
  }
}

/// Le juste prix sur le téléphone
class JpPlay extends StatelessWidget {
  const JpPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '💶', title: 'Le juste prix', sub: 'Un objet s’affiche : tape son prix. Le plus proche gagne !'),
      'ask' => ListView(padding: const EdgeInsets.fromLTRB(18, 44, 18, 18), children: [
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
          const SizedBox(height: 18),
          Center(child: PbPhoto(id: live.s('img'), emoji: live.s('emoji') ?? '🛒', size: 120)),
          const SizedBox(height: 8),
          Text(live.s('name') ?? '', textAlign: TextAlign.center, style: Pb.t(24, weight: 700)),
          Text(live.s('detail') ?? '', textAlign: TextAlign.center, style: Pb.t(16, color: Pb.muted)),
          const SizedBox(height: 22),
          PhoneNumberInput(
            key: ValueKey('jp-${live.i('index')}'),
            sent: you?['answer'] as num?,
            decimal: true,
            suffix: ' €',
            hint: 'Prix',
            onSubmit: (v) => send({'t': 'game_msg', 'm': {'t': 'jp_guess', 'r': live.i('index'), 'v': v}}),
          ),
        ]),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _reveal() {
    final g = you.yi('gain') ?? 0;
    final mine = you?['answer'] as num?;
    final exact = you.yb('exact');
    return PhoneCenter(
      emoji: g >= 500 ? '🎯' : (g > 0 ? '👍' : '💸'),
      title: 'Prix : ${euros(live['price'] as num? ?? 0)}',
      color: g > 0 ? Pb.green : Pb.text,
      extra: Column(children: [
        Text(mine == null ? 'Pas de réponse' : 'Tu as dit ${euros(mine)}', style: Pb.t(20, color: Pb.muted)),
        if (exact) Text('Le juste prix !', style: Pb.t(26, weight: 700, color: Pb.yellow)),
        if (g > 0) Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)),
      ]),
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}
