import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// Scène du film (TMDB), qui apparaît en fondu une fois chargée
class CineScene extends StatelessWidget {
  const CineScene({super.key, required this.url, this.radius = 30});
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Pb.card,
      alignment: Alignment.center,
      child: Text('🎬', style: TextStyle(fontSize: radius * 3)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url == null || url!.isEmpty
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (_, child, frame, sync) => sync
                    ? child
                    : Stack(fit: StackFit.expand, children: [
                        placeholder,
                        AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 400), child: child),
                      ]),
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

/// Quiz cinéma sur la TV : l'image en grand ; les 4 titres sont seulement sur les téléphones
class CineTv extends StatelessWidget {
  const CineTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🎬',
          title: 'Quiz cinéma',
          sub: '${live.s('category') ?? ''} · ${live.i('count')} images',
          rules: [
            'Une scène d’un film s’affiche : trouve son titre parmi 4 sur ton téléphone.',
            live['withHint'] == true
                ? 'Plus tu es rapide, plus tu marques. Indice à 10 s de la fin, mais ça rapporte moins !'
                : 'Plus tu es rapide, plus tu marques !',
          ],
          live: live),
      'load' || 'ask' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'podium' || ph == 'intro' ? ph : 'round'}-${ph == 'reveal' ? 'r' : ''}${live.i('index')}', child: body);
  }

  Widget _round() {
    final ph = live.phase;
    final reveal = ph == 'reveal';
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 36, 60, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(
          label: 'Image',
          index: live.i('index'),
          count: live.i('count'),
          live: ph == 'ask' ? live : null,
          extra: TvChip(text: live.s('category') ?? '', color: Pb.yellow, size: 36),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Stack(children: [
                  CineScene(url: live.s('image')),
                  if (!reveal && (live.s('hint') ?? '').isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 26,
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: .5, end: 1),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) => Transform.scale(scale: v, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                            decoration: BoxDecoration(
                              color: Pb.bg.withValues(alpha: .88),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: Pb.yellow, width: 4),
                            ),
                            child: Text('💡 ${live.s('hint')}', style: Pb.t(40, weight: 700, color: Pb.yellow)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 40),
            SizedBox(width: 470, child: reveal ? _answer() : _waiting()),
          ]),
        ),
        Align(alignment: Alignment.centerRight, child: Text('Images : TMDB', style: Pb.t(22, color: Pb.muted))),
      ]),
    );
  }

  Widget _waiting() {
    if (live.phase == 'load') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Prêts ?', style: Pb.t(80, weight: 700)),
        Text('L’image arrive… 🍿', style: Pb.t(40, color: Pb.muted)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quel est ce film ?', style: Pb.t(72, weight: 700, height: 1.05)),
      const SizedBox(height: 14),
      Text('Les réponses sont sur ton téléphone 📱', style: Pb.t(34, color: Pb.muted)),
      const Spacer(),
      SizedBox(height: 200, child: TvWhoDone(room: room, done: live.pids('answered').toSet())),
    ]);
  }

  Widget _answer() {
    final poster = live.s('poster') ?? '';
    final sub = [if (live['year'] != null) '${live['year']}', if ((live.s('director') ?? '').isNotEmpty) 'de ${live.s('director')}'].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (poster.isNotEmpty)
          Container(
            width: 150,
            height: 225,
            margin: const EdgeInsets.only(right: 22),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))]),
            clipBehavior: Clip.antiAlias,
            child: Image.network(poster, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Pb.card)),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(live.s('title') ?? '', maxLines: 4, overflow: TextOverflow.ellipsis, style: Pb.t(50, weight: 700, color: Pb.yellow, height: 1.05)),
            const SizedBox(height: 8),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(28, color: Pb.muted)),
          ]),
        ),
      ]),
      const SizedBox(height: 26),
      Expanded(child: TvGains(room: room, ranking: live.ranking)),
    ]);
  }
}

/// Quiz cinéma sur le téléphone : les 4 titres
class CinePlay extends StatelessWidget {
  const CinePlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final hint = live.s('hint') ?? '';
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🎬', title: 'Quiz cinéma', sub: 'Regarde la scène sur la TV et trouve le film. Un seul essai !'),
      'load' => const PhoneCenter(emoji: '🍿', title: 'Prêt ?', sub: 'L’image arrive sur la TV…'),
      'ask' => Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
            const SizedBox(height: 12),
            Text('🎬 Quel est ce film ?', textAlign: TextAlign.center, style: Pb.t(24, weight: 700)),
            const SizedBox(height: 4),
            Text(
              hint.isNotEmpty ? '💡 $hint' : 'regarde l’image sur la TV',
              textAlign: TextAlign.center,
              style: Pb.t(16, weight: 600, color: hint.isNotEmpty ? Pb.yellow : Pb.muted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PhoneChoices(
                choices: live.pids('choices'),
                picked: you.yi('answer'),
                onPick: (i) => send({'t': 'game_msg', 'm': {'t': 'cine_pick', 'r': live.i('index'), 'choice': i}}),
              ),
            ),
          ]),
        ),
      'reveal' => Column(children: [
          Expanded(child: phoneGain(you, good: 'Bien vu ! 🎬', none: 'Raté !')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Text('C’était : ${live.s('title') ?? ''}', textAlign: TextAlign.center, style: Pb.t(20, weight: 600, color: Pb.yellow)),
          ),
        ]),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }
}
