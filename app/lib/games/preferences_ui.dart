import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// Qui préfère… ? sur la TV
class PrfTv extends StatelessWidget {
  const PrfTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '💖',
          title: 'Qui préfère… ?',
          sub: 'Couleur, plat, saison… préférés',
          rules: const [
            'Chacun répond en secret sur son téléphone (ne montre pas ton écran 😉).',
            'Puis la TV demande « Qui préfère… ? » : devine qui a fait ce choix !',
          ],
          live: live),
      'fill' => _fill(),
      'ask' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'reveal' ? 'ask' : ph}-${live.i('index')}', child: body);
  }

  Widget _fill() => Padding(
        padding: const EdgeInsets.fromLTRB(80, 60, 80, 50),
        child: Column(children: [
          const Spacer(),
          const Text('🤫💖', style: TextStyle(fontSize: 140)),
          Text('Répondez en secret', style: Pb.t(84, weight: 700)),
          const SizedBox(height: 18),
          Wrap(spacing: 18, runSpacing: 14, alignment: WrapAlignment.center, children: [
            for (final q in live.pids('questions')) TvChip(text: q, size: 36),
          ]),
          const Spacer(),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
          const SizedBox(height: 26),
          SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('done').toSet(), label: 'ont répondu')),
        ]),
      );

  Widget _round() {
    final reveal = live.phase == 'reveal';
    final holders = live.pids('holders');
    final picks = {for (final e in ((live['picks'] as Map?) ?? const {}).entries) e.key as String: e.value as String};
    final found = [for (final e in picks.entries) if (holders.contains(e.value)) e.key];
    final votes = live.i('votes');
    final names = [for (final h in holders) room.player(h)?.name ?? '?'];
    final who = names.length <= 1 ? (names.firstOrNull ?? '?') : '${names.sublist(0, names.length - 1).join(', ')} et ${names.last}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(
          label: 'Manche',
          index: live.i('index'),
          count: live.i('count'),
          live: reveal ? null : live,
          extra: reveal ? null : TvChip(text: '$votes vote${votes > 1 ? 's' : ''}', size: 34),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(live.s('ask') ?? '', style: Pb.t(reveal ? 48 : 60, weight: 600, color: Pb.muted)),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .5, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Text(live.s('value') ?? '', style: Pb.t(reveal ? 96 : 140, weight: 700, color: Pb.yellow)),
                ),
                if (reveal) ...[
                  const SizedBox(height: 26),
                  Wrap(spacing: 26, alignment: WrapAlignment.center, children: [
                    for (final h in holders)
                      if (room.player(h) case final p?) PbAvatar(size: holders.length > 3 ? 120 : 170, emoji: p.emoji, color: p.color, photoPath: p.photo),
                  ]),
                  const SizedBox(height: 14),
                  Text('C’était $who !', textAlign: TextAlign.center, style: Pb.t(64, weight: 700)),
                  const SizedBox(height: 12),
                  if (found.isEmpty)
                    Text('Personne n’a trouvé 😏', style: Pb.t(40, color: Pb.muted))
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Trouvé par  ', style: Pb.t(38, color: Pb.muted)),
                      TvAvatarRow(room: room, pids: found, size: 64),
                    ]),
                ] else ...[
                  const SizedBox(height: 18),
                  Text('Devine sur ton téléphone !', style: Pb.t(44, color: Pb.text)),
                ],
              ]),
            ),
          ),
        ),
        if (reveal) SizedBox(height: 90, child: TvGains(room: room, ranking: live.ranking)),
        if (!reveal) TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
      ]),
    );
  }
}

/// Qui préfère… ? sur le téléphone
class PrfPlay extends StatelessWidget {
  const PrfPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
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
      'intro' => const PhoneCenter(emoji: '💖', title: 'Qui préfère… ?', sub: 'Tu vas répondre en secret à quelques questions sur tes goûts. Ne montre ton écran à personne !'),
      'fill' => _PrfForm(key: const ValueKey('fill'), you: you, live: live, send: send),
      'ask' => _ask(),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: ph == 'fill' ? 'fill' : '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _ask() {
    if (you.yb('mine')) {
      return PhoneCenter(
        emoji: '🤫',
        title: 'C’est ton choix !',
        sub: '${live.s('value') ?? ''}\n\nFais comme si de rien n’était… Si les autres se trompent, tu gagnes des points.',
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 44, 16, 16), children: [
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 12),
      Text(live.s('ask') ?? '', textAlign: TextAlign.center, style: Pb.t(17, color: Pb.muted)),
      Text(live.s('value') ?? '', textAlign: TextAlign.center, style: Pb.t(28, weight: 700, color: Pb.yellow, height: 1.15)),
      const SizedBox(height: 8),
      Text(you.ys('answer') == null ? 'Qui a choisi ça ?' : 'Vote envoyé ! Regarde la TV 📺',
          textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: you.ys('answer') == null ? Pb.text : Pb.green)),
      const SizedBox(height: 12),
      PhonePlayerPick(
        room: room,
        myPid: myPid,
        picked: you.ys('answer'),
        onPick: (pid) => send({'t': 'game_msg', 'm': {'t': 'prf_guess', 'r': live.i('index'), 'pid': pid}}),
      ),
    ]);
  }

  Widget _reveal() {
    final holders = live.pids('holders');
    final g = you.yi('gain') ?? 0;
    final mine = holders.contains(myPid);
    final names = [for (final h in holders) if (h != myPid) room.player(h)?.name ?? '?'];
    return PhoneCenter(
      emoji: mine ? '😎' : (g > 0 ? '🎯' : '🙈'),
      title: mine ? (names.isEmpty ? 'C’était toi !' : 'C’était toi et ${names.join(', ')} !') : 'C’était ${names.join(', ')}',
      color: g > 0 ? Pb.green : Pb.text,
      extra: g > 0 ? Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)) : null,
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}

/// Les questions secrètes : un choix à toucher (ou l'année à taper), envoyé tout de suite
class _PrfForm extends StatefulWidget {
  const _PrfForm({super.key, required this.you, required this.live, required this.send});
  final Map<String, dynamic>? you;
  final Map<String, dynamic> live;
  final void Function(Map<String, dynamic>) send;

  @override
  State<_PrfForm> createState() => _PrfFormState();
}

class _PrfFormState extends State<_PrfForm> {
  final _year = TextEditingController();

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _form => [for (final f in (widget.you?['form'] as List?) ?? const []) f as Map<String, dynamic>];
  List<String?> get _filled => [for (final v in (widget.you?['filled'] as List?) ?? const []) v as String?];

  void _send(int q, String v) {
    HapticFeedback.selectionClick();
    widget.send({'t': 'game_msg', 'm': {'t': 'prf_fill', 'q': q, 'v': v}});
  }

  @override
  Widget build(BuildContext context) {
    final form = _form, filled = _filled;
    final all = form.isNotEmpty && List.generate(form.length, (i) => i < filled.length && filled[i] != null).every((x) => x);
    final maxYear = widget.you.yi('maxYear') ?? DateTime.now().year;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 44, 18, 18), children: [
      TimeBar(endsIn: widget.live.endsIn, duration: widget.live.duration, height: 8),
      const SizedBox(height: 14),
      Text('🤫 Réponds en secret', textAlign: TextAlign.center, style: Pb.t(24, weight: 700)),
      const SizedBox(height: 4),
      Text('Touche ta réponse, tu peux changer d’avis jusqu’à la fin.', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.muted)),
      const SizedBox(height: 18),
      for (var i = 0; i < form.length; i++) ...[
        Row(children: [
          Expanded(child: Text(form[i]['q'] as String? ?? '', style: Pb.t(19, weight: 700))),
          if (i < filled.length && filled[i] != null) const Icon(Icons.check_circle_rounded, color: Pb.green, size: 26),
        ]),
        const SizedBox(height: 8),
        if (form[i]['year'] == true)
          Row(children: [
            Expanded(
              child: TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                onChanged: (_) => setState(() {}),
                onSubmitted: (t) => _sendYear(i, t, maxYear),
                style: Pb.t(20, weight: 600),
                decoration: InputDecoration(hintText: i < filled.length && filled[i] != null ? filled[i] : 'ex. 1985', counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _yearOk(_year.text, maxYear) ? () => _sendYear(i, _year.text, maxYear) : null,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(backgroundColor: Pb.pink, minimumSize: const Size(52, 52)),
            ),
          ])
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in (form[i]['options'] as List? ?? const []).cast<String>())
              ChoiceChip(
                label: Text(o, style: Pb.t(16, weight: 600, color: i < filled.length && filled[i] == o ? Pb.bg : Pb.text)),
                selected: i < filled.length && filled[i] == o,
                selectedColor: Pb.yellow,
                backgroundColor: Pb.card,
                showCheckmark: false,
                onSelected: (_) => _send(i, o),
              ),
          ]),
        const SizedBox(height: 22),
      ],
      if (all) Text('C’est envoyé ! On attend les autres… 🤫', textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: Pb.green)),
    ]);
  }

  bool _yearOk(String t, int maxYear) {
    final y = int.tryParse(t);
    return y != null && y >= 1920 && y <= maxYear;
  }

  void _sendYear(int q, String t, int maxYear) {
    if (!_yearOk(t, maxYear)) return;
    _send(q, t);
    FocusScope.of(context).unfocus();
    _year.clear();
  }
}
