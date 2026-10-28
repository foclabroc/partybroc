import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// L'emoji géant qui se dézoome au fil du temps (calé sur le chrono du serveur).
/// À la révélation : affiché en entier.
class ZoomPicture extends StatefulWidget {
  const ZoomPicture({super.key, required this.e, required this.fx, required this.fy, required this.endsIn, required this.duration, required this.full, this.size = 620});
  final String e;
  final double fx, fy;
  final int endsIn, duration;
  final bool full;
  final double size;

  @override
  State<ZoomPicture> createState() => _ZoomPictureState();
}

class _ZoomPictureState extends State<ZoomPicture> with SingleTickerProviderStateMixin {
  late DateTime _end;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _end = DateTime.now().add(Duration(milliseconds: widget.endsIn));
    _ticker = createTicker((_) => setState(() {}))..start();
  }

  @override
  void didUpdateWidget(ZoomPicture old) {
    super.didUpdateWidget(old);
    final fresh = DateTime.now().add(Duration(milliseconds: widget.endsIn));
    if (fresh.difference(_end).inMilliseconds.abs() > 400) _end = fresh;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _end.difference(DateTime.now()).inMilliseconds.clamp(0, widget.duration);
    // 0 au début → 1 à la fin ; le zoom part de ×16 et descend vers ×1,4 (jamais en entier avant la fin)
    final t = widget.duration == 0 ? 1.0 : 1 - left / widget.duration;
    final scale = widget.full ? 1.0 : 1.4 + 14.6 * pow(1 - t, 2.2);
    final s = widget.size;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(s * .08),
        border: Border.all(color: Pb.cardHi, width: s * .015),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: s * .06)],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedScale(
        duration: Duration(milliseconds: widget.full ? 700 : 0),
        curve: Curves.easeOutCubic,
        scale: scale,
        alignment: Alignment(widget.fx * 2 - 1, widget.fy * 2 - 1),
        child: Center(child: Text(widget.e, style: TextStyle(fontSize: s * .72, height: 1.15))),
      ),
    );
  }
}

/// Zoom mystère sur la TV
class ZoomTv extends StatelessWidget {
  const ZoomTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🔍',
          title: 'Zoom mystère',
          sub: '${live.i('count')} images',
          rules: const ['L’image est très zoomée, puis elle se dézoome petit à petit.', 'Un seul essai : plus tu trouves tôt, plus tu marques !'],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Image', index: live.i('index'), count: live.i('count'), live: reveal ? null : live),
        const SizedBox(height: 20),
        Expanded(
          child: Row(children: [
            ZoomPicture(
              key: ValueKey('z${live.i('index')}'),
              e: live.s('e') ?? '❓',
              fx: (live['fx'] as num?)?.toDouble() ?? .5,
              fy: (live['fy'] as num?)?.toDouble() ?? .5,
              endsIn: live.endsIn,
              duration: live.duration,
              full: reveal,
            ),
            const SizedBox(width: 60),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(reveal ? 'C’était…' : 'Qu’est-ce que c’est ?', style: Pb.t(60, weight: 700)),
                const SizedBox(height: 36),
                TvChoices(room: room, choices: live.pids('choices'), correct: reveal ? live.i('correct') : null, picks: picks, height: 120),
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

/// Zoom mystère sur le téléphone
class ZoomPlay extends StatelessWidget {
  const ZoomPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🔍', title: 'Zoom mystère', sub: 'Regarde l’image sur la TV et trouve ce que c’est. Un seul essai !'),
      'ask' => Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
            const SizedBox(height: 14),
            Text('Qu’est-ce que c’est ? 🔍', textAlign: TextAlign.center, style: Pb.t(22, weight: 700)),
            const SizedBox(height: 14),
            Expanded(
              child: PhoneChoices(
                choices: live.pids('choices'),
                picked: you.yi('answer'),
                onPick: (i) => send({'t': 'game_msg', 'm': {'t': 'zoom_pick', 'r': live.i('index'), 'choice': i}}),
              ),
            ),
          ]),
        ),
      'reveal' => phoneGain(you, good: 'Bien vu ! 👀', none: 'Raté !'),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }
}
