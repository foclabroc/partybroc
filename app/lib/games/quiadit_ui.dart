import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// Qui a dit ça ? sur la TV
class QadTv extends StatelessWidget {
  const QadTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '💬',
          title: 'Qui a dit ça ?',
          sub: 'Réponses secrètes',
          rules: const ['Réponds en secret à 2 questions sur ton téléphone.', 'Puis devine qui a écrit chaque réponse. L’auteur, lui, garde un air innocent !'],
          live: live),
      'write' => _write(),
      'ask' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'reveal' ? 'ask' : ph}-${live.i('index')}', child: body);
  }

  Widget _write() => Padding(
        padding: const EdgeInsets.fromLTRB(80, 60, 80, 50),
        child: Column(children: [
          const Spacer(),
          const Text('✍️🤫', style: TextStyle(fontSize: 150)),
          Text('Chacun répond en secret', style: Pb.t(84, weight: 700)),
          const SizedBox(height: 12),
          Text('sur son téléphone, sans montrer aux autres !', style: Pb.t(44, color: Pb.muted)),
          const Spacer(),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
          const SizedBox(height: 26),
          SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('done').toSet(), label: 'ont fini')),
        ]),
      );

  Widget _round() {
    final reveal = live.phase == 'reveal';
    final author = reveal ? room.player(live.s('author') ?? '') : null;
    final picks = {for (final e in ((live['picks'] as Map?) ?? const {}).entries) e.key as String: e.value as String};
    final found = [for (final e in picks.entries) if (e.value == live.s('author')) e.key];
    // Pendant le vote : seulement le nombre de votes (montrer qui a voté trahirait l'auteur)
    final votes = live.pids('answered').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(
          label: 'Réponse',
          index: live.i('index'),
          count: live.i('count'),
          live: reveal ? null : live,
          extra: reveal ? null : TvChip(text: '$votes vote${votes > 1 ? 's' : ''}', size: 34),
        ),
        const SizedBox(height: 20),
        Text(live.s('prompt') ?? '', textAlign: TextAlign.center, style: Pb.t(46, color: Pb.muted)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
          decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(40), border: Border.all(color: Pb.cardHi, width: 4)),
          child: Text('« ${live.s('text') ?? ''} »', textAlign: TextAlign.center, style: Pb.t(84, weight: 700, height: 1.15)),
        ),
        Expanded(
          child: Center(
            child: reveal && author != null
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    PbAvatar(size: 200, emoji: author.emoji, color: author.color, photoPath: author.photo),
                    const SizedBox(width: 40),
                    Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('C’était ${author.name} !', style: Pb.t(80, weight: 700, color: Pb.yellow)),
                      const SizedBox(height: 10),
                      if (found.isEmpty)
                        Text('Personne n’a deviné 😏', style: Pb.t(44, color: Pb.muted))
                      else
                        Row(children: [
                          Text('Trouvé par ', style: Pb.t(40, color: Pb.muted)),
                          TvAvatarRow(room: room, pids: found, size: 70),
                        ]),
                    ]),
                  ])
                : Text('Qui a écrit ça ? 🤔', style: Pb.t(70, weight: 700)),
          ),
        ),
        if (reveal) SizedBox(height: 90, child: TvGains(room: room, ranking: live.ranking)),
        if (!reveal) TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
      ]),
    );
  }
}

/// Qui a dit ça ? sur le téléphone
class QadPlay extends StatelessWidget {
  const QadPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
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
      'intro' => const PhoneCenter(emoji: '💬', title: 'Qui a dit ça ?', sub: 'Tu vas répondre en secret à 2 questions. Ne montre ton écran à personne !'),
      'write' => _QadWrite(
          key: const ValueKey('write'),
          prompts: [for (final p in (you?['prompts'] as List?) ?? const []) p as String],
          written: [for (final w in (you?['written'] as List?) ?? const []) w as String?],
          live: live,
          send: send,
        ),
      'ask' => _ask(),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: ph == 'write' ? 'write' : '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _ask() {
    if (you.yb('mine')) {
      return const PhoneCenter(emoji: '🤫', title: 'C’est ta réponse !', sub: 'Fais comme si de rien n’était… Si les autres se trompent, tu gagnes des points.');
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 44, 16, 16), children: [
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 12),
      Text(live.s('prompt') ?? '', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.muted)),
      Text('« ${live.s('text') ?? ''} »', textAlign: TextAlign.center, style: Pb.t(24, weight: 700, height: 1.15)),
      const SizedBox(height: 8),
      Text(you.ys('answer') == null ? 'Qui a écrit ça ?' : 'Vote envoyé ! Regarde la TV 📺',
          textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: you.ys('answer') == null ? Pb.text : Pb.green)),
      const SizedBox(height: 12),
      PhonePlayerPick(
        room: room,
        myPid: myPid,
        picked: you.ys('answer'),
        onPick: (pid) => send({'t': 'game_msg', 'm': {'t': 'qad_guess', 'r': live.i('index'), 'pid': pid}}),
      ),
    ]);
  }

  Widget _reveal() {
    final author = room.player(live.s('author') ?? '');
    final g = you.yi('gain') ?? 0;
    final mine = live.s('author') == myPid;
    return PhoneCenter(
      emoji: mine ? '😎' : (g > 0 ? '🎯' : '🙈'),
      title: mine ? 'C’était toi !' : 'C’était ${author?.name ?? '?'}',
      color: g > 0 ? Pb.green : Pb.text,
      extra: g > 0 ? Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)) : null,
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}

/// Les 2 questions secrètes : un champ chacune, envoyées une par une
class _QadWrite extends StatefulWidget {
  const _QadWrite({super.key, required this.prompts, required this.written, required this.live, required this.send});
  final List<String> prompts;
  final List<String?> written;
  final Map<String, dynamic> live;
  final void Function(Map<String, dynamic>) send;

  @override
  State<_QadWrite> createState() => _QadWriteState();
}

class _QadWriteState extends State<_QadWrite> {
  late final _c = [for (var i = 0; i < 2; i++) TextEditingController(text: i < widget.written.length ? widget.written[i] ?? '' : '')];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  bool _sent(int i) => i < widget.written.length && (widget.written[i] ?? '').isNotEmpty && widget.written[i] == _c[i].text.trim();

  void _send(int i) {
    final t = _c[i].text.trim();
    if (t.isEmpty) return;
    HapticFeedback.mediumImpact();
    widget.send({'t': 'game_msg', 'm': {'t': 'qad_write', 'i': i, 'text': t}});
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final all = List.generate(widget.prompts.length, _sent).every((x) => x);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 44, 18, 18), children: [
      TimeBar(endsIn: widget.live.endsIn, duration: widget.live.duration, height: 8),
      const SizedBox(height: 14),
      Text('🤫 Réponds en secret', textAlign: TextAlign.center, style: Pb.t(24, weight: 700)),
      const SizedBox(height: 16),
      for (var i = 0; i < widget.prompts.length; i++) ...[
        Text(widget.prompts[i], style: Pb.t(18, weight: 600)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _c[i],
              maxLength: 60,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _send(i),
              style: Pb.t(18),
              decoration: const InputDecoration(hintText: 'Ta réponse…', counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          _sent(i)
              ? const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.check_circle_rounded, color: Pb.green, size: 32))
              : IconButton.filled(
                  onPressed: _c[i].text.trim().isEmpty ? null : () => _send(i),
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(backgroundColor: Pb.pink, minimumSize: const Size(52, 52)),
                ),
        ]),
        const SizedBox(height: 16),
      ],
      if (all) Text('C’est envoyé ! On attend les autres… 🤫', textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: Pb.green)),
    ]);
  }
}
