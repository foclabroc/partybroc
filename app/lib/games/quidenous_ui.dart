import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

const _lead = 'Qui est le plus susceptible de…';

/// Qui de nous ? sur la TV
class QdnTv extends StatelessWidget {
  const QdnTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '👀',
          title: 'Qui de nous ?',
          sub: '${live.i('count')} questions',
          rules: const [
            'Vote sur ton téléphone pour le joueur qui correspond le mieux.',
            'Les votes sont anonymes. +100 si tu votes comme la majorité !',
          ],
          live: live),
      'vote' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: ph == 'reveal' ? 'vote-${live.i('index')}' : '$ph-${live.i('index')}', child: body);
  }

  Widget _round() {
    final reveal = live.phase == 'reveal';
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 50, 80, 50),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Question', index: live.i('index'), count: live.i('count'), live: reveal ? null : live),
        const SizedBox(height: 24),
        Text(_lead, textAlign: TextAlign.center, style: Pb.t(44, weight: 500, color: Pb.muted)),
        const SizedBox(height: 10),
        Text(live.s('prompt') ?? '', textAlign: TextAlign.center, style: Pb.t(78, weight: 700, height: 1.1)),
        const SizedBox(height: 30),
        Expanded(child: reveal ? _tally() : _candidates()),
        if (!reveal) ...[
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
          const SizedBox(height: 30),
          SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('voted').toSet(), label: 'ont voté')),
        ] else
          SizedBox(height: 90, child: TvGains(room: room, ranking: live.ranking)),
      ]),
    );
  }

  // Pendant le vote : tous les joueurs, sans indiquer qui a reçu des voix
  Widget _candidates() {
    final players = room.players.where((p) => p.connected).toList();
    return Center(
      child: Wrap(spacing: 44, runSpacing: 28, alignment: WrapAlignment.center, children: [
        for (final p in players)
          Column(mainAxisSize: MainAxisSize.min, children: [
            PbAvatar(size: players.length > 6 ? 120 : 150, emoji: p.emoji, color: p.color, photoPath: p.photo),
            const SizedBox(height: 10),
            Text(p.name, style: Pb.t(34, weight: 600)),
          ]),
      ]),
    );
  }

  Widget _tally() {
    final tally = live.maps('tally');
    final winners = live.pids('winners').toSet();
    if (tally.isEmpty) return Center(child: Text('Personne n’a voté… 🦗', style: Pb.t(54, weight: 600, color: Pb.muted)));
    final top = tally.first['count'] as int;
    return Center(
      child: Wrap(spacing: 40, runSpacing: 24, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.end, children: [
        for (final t in tally.take(6))
          if (room.player(t['pid'] as String) case final p?)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (t['count'] as int) / top),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              builder: (_, f, _) => Column(mainAxisSize: MainAxisSize.min, children: [
                if (winners.contains(p.pid)) const Text('👑', style: TextStyle(fontSize: 54, height: 1)),
                PbAvatar(size: winners.contains(p.pid) ? 170 : 120, emoji: p.emoji, color: p.color, photoPath: p.photo),
                const SizedBox(height: 10),
                Text(p.name, style: Pb.t(winners.contains(p.pid) ? 44 : 34, weight: 700)),
                Text('${t['count']} vote${(t['count'] as int) > 1 ? 's' : ''}',
                    style: Pb.t(34, weight: 600, color: winners.contains(p.pid) ? Pb.yellow : Pb.muted)),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 10 + 110 * f.clamp(0, 1.2),
                  decoration: BoxDecoration(
                    color: Pb.playerColor(p.color),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
              ]),
            ),
      ]),
    );
  }
}

/// Qui de nous ? sur le téléphone
class QdnPlay extends StatelessWidget {
  const QdnPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final String? myPid;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '👀', title: 'Qui de nous ?', sub: 'Regarde la question sur la TV et vote ici pour un joueur.'),
      'vote' => _vote(),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(
      stepKey: '$ph-${live.i('index')}-${you.ys('vote')}',
      isHost: isHost,
      phase: ph,
      send: send,
      child: body,
    );
  }

  Widget _vote() {
    final voted = you.ys('vote');
    final others = room.players.where((p) => p.pid != myPid).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 44, 16, 16), children: [
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 14),
      Text(_lead, textAlign: TextAlign.center, style: Pb.t(16, color: Pb.muted)),
      Text(live.s('prompt') ?? '', textAlign: TextAlign.center, style: Pb.t(22, weight: 700, height: 1.15)),
      const SizedBox(height: 16),
      if (voted != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Vote envoyé ! Regarde la TV 📺', textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: Pb.green)),
        ),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          for (final p in others)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: voted != null && voted != p.pid ? .3 : 1,
              child: Material(
                color: voted == p.pid ? Pb.cardHi : Pb.card,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: voted != null
                      ? null
                      : () {
                          HapticFeedback.heavyImpact();
                          send({'t': 'game_msg', 'm': {'t': 'qdn_vote', 'r': live.i('index'), 'pid': p.pid}});
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: voted == p.pid ? Pb.pink : Colors.transparent, width: 3),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      PbAvatar(size: 70, emoji: p.emoji, color: p.color, photoPath: p.photo),
                      const SizedBox(height: 8),
                      Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(18, weight: 600)),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    ]);
  }

  Widget _reveal() {
    final winners = live.pids('winners');
    final names = [for (final w in winners) room.player(w)?.name ?? '?'];
    final me = winners.contains(myPid);
    final g = you.yi('gain') ?? 0;
    return PhoneCenter(
      emoji: me ? '🙈' : (g > 0 ? '🎯' : '🤷'),
      title: winners.isEmpty ? 'Personne n’a voté' : (me ? 'C’est toi !' : 'Le groupe a choisi ${names.join(' et ')}'),
      color: me ? Pb.yellow : Pb.text,
      extra: g > 0 ? Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)) : null,
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}
