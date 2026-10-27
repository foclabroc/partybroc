import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

const _letters = 'ABCDEFGHIJ';

/// La phrase avec son trou mis en valeur
Widget prompt(String? text, double size, {TextAlign align = TextAlign.center, Color hole = Pb.pink}) {
  final parts = (text ?? '').split('___');
  return Text.rich(
    TextSpan(children: [
      for (var i = 0; i < parts.length; i++) ...[
        TextSpan(text: parts[i]),
        if (i < parts.length - 1) TextSpan(text: '______', style: TextStyle(color: hole)),
      ],
    ]),
    textAlign: align,
    style: Pb.t(size, weight: 700, height: 1.15),
  );
}

/// Réponses drôles sur la TV
class DrlTv extends StatelessWidget {
  const DrlTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '😂',
          title: 'Réponses drôles',
          sub: '${live.i('count')} manches',
          rules: const [
            'Complète la phrase sur ton téléphone, le plus drôle possible.',
            'Puis vote pour ta réponse préférée : 100 points par vote reçu !',
          ],
          live: live),
      'write' => _write(),
      'vote' || 'reveal' => _answers(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: ph == 'reveal' ? 'vote-${live.i('index')}' : '$ph-${live.i('index')}', child: body);
  }

  Widget _write() => Padding(
        padding: const EdgeInsets.fromLTRB(80, 50, 80, 50),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TvHeader(label: 'Manche', index: live.i('index'), count: live.i('count'), live: live),
          Expanded(child: Center(child: prompt(live.s('prompt'), 84))),
          Text('✍️  Écrivez vos réponses sur vos téléphones…', textAlign: TextAlign.center, style: Pb.t(40, color: Pb.muted)),
          const SizedBox(height: 40),
          SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('answered').toSet())),
        ]),
      );

  Widget _answers() {
    final reveal = live.phase == 'reveal';
    final answers = live.maps('answers');
    final cols = answers.length <= 4 ? 2 : 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(70, 44, 70, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Manche', index: live.i('index'), count: live.i('count'), live: reveal ? null : live),
        const SizedBox(height: 14),
        prompt(live.s('prompt'), 54),
        const SizedBox(height: 26),
        Expanded(
          child: answers.isEmpty
              ? Center(child: Text('Pas de réponse cette fois… 😶', style: Pb.t(50, color: Pb.muted)))
              : LayoutBuilder(builder: (_, c) {
                  // Les cartes se partagent toute la hauteur disponible
                  const gap = 22.0;
                  final rows = (answers.length / cols).ceil();
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;
                  final h = ((c.maxHeight - gap * (rows - 1)) / rows).clamp(120.0, 260.0);
                  return GridView.count(
                    crossAxisCount: cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: w / h,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (final a in answers) _card(a, reveal)],
                  );
                }),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 90,
          child: reveal
              ? TvGains(room: room, ranking: live.ranking)
              : TvWhoDone(room: room, done: live.pids('voted').toSet(), label: 'ont voté'),
        ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> a, bool reveal) {
    final i = a['i'] as int;
    final best = a['best'] == true;
    final author = reveal ? room.player(a['author'] as String) : null;
    final voters = [for (final v in (a['voters'] as List?) ?? const []) room.player(v as String)].whereType<PlayerView>();
    final votes = (a['votes'] as num?)?.toInt() ?? 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      decoration: BoxDecoration(
        color: best ? Pb.cardHi : Pb.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: best ? Pb.yellow : Pb.cardHi, width: best ? 5 : 2),
        boxShadow: best ? [BoxShadow(color: Pb.yellow.withValues(alpha: .35), blurRadius: 30)] : null,
      ),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Pb.playerColor(i * 3), shape: BoxShape.circle),
          child: Text(_letters[i % _letters.length], style: Pb.t(36, weight: 700, color: Pb.bg)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('«\u00A0${a['text']}\u00A0»', maxLines: 3, overflow: TextOverflow.ellipsis, style: Pb.t(40, weight: 600, height: 1.15)),
            if (reveal) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (author != null) ...[
                  PbAvatar(size: 40, emoji: author.emoji, color: author.color, photoPath: author.photo),
                  const SizedBox(width: 8),
                  Text(author.name, style: Pb.t(28, weight: 600, color: Pb.muted)),
                ],
                const Spacer(),
                if (best) Text(a['unanimous'] == true ? '🏆 Unanime ! ' : '⭐ ', style: Pb.t(28, weight: 700, color: Pb.yellow)),
                Text('$votes vote${votes > 1 ? 's' : ''}', style: Pb.t(28, weight: 700, color: best ? Pb.yellow : Pb.text)),
                for (final v in voters.take(5))
                  Padding(padding: const EdgeInsets.only(left: 4), child: PbAvatar(size: 34, emoji: v.emoji, color: v.color, photoPath: v.photo)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Réponses drôles sur le téléphone
class DrlPlay extends StatefulWidget {
  const DrlPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<DrlPlay> createState() => _DrlPlayState();
}

class _DrlPlayState extends State<DrlPlay> {
  final _ctl = TextEditingController();
  bool _editing = true;
  int _round = -1;

  Map<String, dynamic> get live => widget.live;
  Map<String, dynamic>? get you => widget.you;

  @override
  void didUpdateWidget(DrlPlay old) {
    super.didUpdateWidget(old);
    // Nouvelle manche : champ vide
    if (live.i('index') != _round && live.phase == 'write') {
      _round = live.i('index');
      _ctl.clear();
      _editing = you.ys('answer') == null;
    }
  }

  @override
  void initState() {
    super.initState();
    _round = live.i('index');
    _editing = you.ys('answer') == null;
    _ctl.text = you.ys('answer') ?? '';
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _sendAnswer() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    widget.send({'t': 'game_msg', 'm': {'t': 'drl_answer', 'r': live.i('index'), 'text': t}});
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '😂', title: 'Réponses drôles', sub: 'Prépare ton meilleur humour…'),
      'write' => _write(),
      'vote' => _vote(),
      'reveal' => phoneGain(you, good: 'Ça a fait rire !', none: 'Pas de vote cette fois'),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(
      stepKey: '$ph-${live.i('index')}-${you.yi('vote')}-$_editing',
      isHost: widget.isHost,
      phase: ph,
      send: widget.send,
      child: body,
    );
  }

  Widget _write() {
    final sent = you.ys('answer');
    return ListView(padding: const EdgeInsets.fromLTRB(18, 44, 18, 18), children: [
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 18),
      prompt(live.s('prompt'), 24),
      const SizedBox(height: 22),
      if (_editing || sent == null) ...[
        TextField(
          controller: _ctl,
          autofocus: true,
          maxLength: 60,
          maxLines: 2,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendAnswer(),
          style: Pb.t(20, weight: 600),
          decoration: const InputDecoration(hintText: 'Ta réponse…'),
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: _sendAnswer, child: const Text('Envoyer')),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(18)),
          child: Text('«\u00A0$sent\u00A0»', textAlign: TextAlign.center, style: Pb.t(20, weight: 600)),
        ),
        const SizedBox(height: 12),
        Text('Réponse envoyée ! On attend les autres…', textAlign: TextAlign.center, style: Pb.t(16, color: Pb.green)),
        TextButton(
          onPressed: () => setState(() {
            _ctl.text = sent;
            _editing = true;
          }),
          child: const Text('Modifier'),
        ),
      ],
    ]);
  }

  Widget _vote() {
    final answers = live.maps('answers');
    final mine = you.yi('mine');
    final voted = you.yi('vote');
    return ListView(padding: const EdgeInsets.fromLTRB(16, 44, 16, 16), children: [
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 12),
      Text('La plus drôle ?', textAlign: TextAlign.center, style: Pb.t(24, weight: 700)),
      if (voted != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Vote envoyé ! Regarde la TV 📺', textAlign: TextAlign.center, style: Pb.t(16, weight: 600, color: Pb.green)),
        ),
      const SizedBox(height: 12),
      for (final a in answers)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _voteTile(a['i'] as int, a['text'] as String, mine == a['i'], voted),
        ),
    ]);
  }

  Widget _voteTile(int i, String text, bool mine, int? voted) {
    final chosen = voted == i;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: mine || (voted != null && !chosen) ? .35 : 1,
      child: Material(
        color: chosen ? Pb.cardHi : Pb.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: mine || voted != null
              ? null
              : () {
                  HapticFeedback.heavyImpact();
                  widget.send({'t': 'game_msg', 'm': {'t': 'drl_vote', 'r': live.i('index'), 'a': i}});
                },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: chosen ? Pb.pink : Colors.transparent, width: 3),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Pb.playerColor(i * 3),
                child: Text(_letters[i % _letters.length], style: Pb.t(18, weight: 700, color: Pb.bg)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: Pb.t(18, weight: 600))),
              if (mine) Text('(toi)', style: Pb.t(14, color: Pb.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
