import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'draw_board.dart';

/// Le mot masqué, lettre par lettre (« _ _ _ » ou lettres dévoilées)
Widget wordMask(String? mask, double size, {Color color = Pb.text}) {
  if (mask == null) return const SizedBox.shrink();
  return Wrap(alignment: WrapAlignment.center, spacing: size * .18, runSpacing: size * .3, children: [
    for (final ch in mask.split(''))
      ch == ' '
          ? SizedBox(width: size * .6)
          : Container(
              width: size * .8,
              padding: EdgeInsets.only(bottom: size * .05),
              decoration: BoxDecoration(
                border: ch == '_' || RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)
                    ? Border(bottom: BorderSide(color: Pb.muted, width: size * .07))
                    : null,
              ),
              child: Text(ch == '_' ? ' ' : ch.toUpperCase(), textAlign: TextAlign.center, style: Pb.t(size, weight: 700, color: color, height: 1.1)),
            ),
  ]);
}

/// Dessin à deviner sur la TV
class DsnTv extends StatelessWidget {
  const DsnTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  PlayerView? get drawer => room.player(live.s('drawer') ?? '');

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'draw' || ph == 'reveal') DrawBoard.instance.ensure(live.i('turn', -1), live.i('strokes'));
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🎨',
          title: 'Dessin à deviner',
          sub: '${live.i('turns')} dessins',
          rules: const [
            'Chacun son tour, un joueur dessine un mot sur son téléphone.',
            'Les autres tapent leurs propositions : le plus rapide marque le plus !',
          ],
          live: live),
      'choose' => _choose(),
      'draw' || 'reveal' => _draw(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: ph == 'reveal' ? 'draw-${live.i('turn')}' : '$ph-${live.i('turn')}', child: body);
  }

  Widget _choose() {
    final d = drawer;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Dessin ${live.i('turn') + 1} / ${live.i('turns')}', style: Pb.t(44, weight: 600, color: Pb.muted)),
        const SizedBox(height: 30),
        if (d != null) PbAvatar(size: 240, emoji: d.emoji, color: d.color, photoPath: d.photo),
        const SizedBox(height: 26),
        Text('${d?.name ?? '?'} choisit un mot…', style: Pb.t(80, weight: 700)),
        const SizedBox(height: 40),
        TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 110),
      ]),
    );
  }

  Widget _draw() {
    final reveal = live.phase == 'reveal';
    final d = drawer;
    final found = live.pids('found').toSet();
    final guessers = room.players.where((p) => p.connected && p.pid != live.s('drawer')).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(70, 50, 70, 50),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 980,
          height: 980,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 40)],
            ),
            child: const DrawView(radius: 36),
          ),
        ),
        const SizedBox(width: 50),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (d != null) PbAvatar(size: 90, emoji: d.emoji, color: d.color, photoPath: d.photo),
              const SizedBox(width: 18),
              Expanded(child: Text('${d?.name ?? '?'} dessine', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(46, weight: 700))),
              if (!reveal) TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 100),
            ]),
            const SizedBox(height: 36),
            if (reveal) Text('C’était…', style: Pb.t(38, color: Pb.muted)),
            wordMask(live.s('mask'), reveal ? 70 : 64, color: reveal ? Pb.yellow : Pb.text),
            if (!reveal && live.s('mask') != null) ...[
              const SizedBox(height: 14),
              Text('${RegExp(r'[\p{L}\p{N}_]', unicode: true).allMatches(live.s('mask')!).length} lettres',
                  style: Pb.t(30, color: Pb.muted)),
            ],
            const SizedBox(height: 40),
            Wrap(spacing: 14, runSpacing: 14, children: [
              for (final p in guessers)
                Stack(clipBehavior: Clip.none, children: [
                  PbAvatar(size: 72, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !found.contains(p.pid)),
                  if (found.contains(p.pid)) const Positioned(right: -6, bottom: -6, child: Text('✅', style: TextStyle(fontSize: 30))),
                ]),
            ]),
            const SizedBox(height: 30),
            Expanded(child: reveal ? _gains() : _feed()),
          ]),
        ),
      ]),
    );
  }

  Widget _feed() {
    final feed = live.maps('feed');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
      for (final f in feed)
        if (room.player(f['pid'] as String) case final p?)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              PbAvatar(size: 44, emoji: p.emoji, color: p.color, photoPath: p.photo),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  f['found'] == true ? '${p.name} a trouvé ! 🎉' : '${p.name} : ${f['text']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Pb.t(34, weight: f['found'] == true ? 700 : 500, color: f['found'] == true ? Pb.green : Pb.text),
                ),
              ),
            ]),
          ),
    ]);
  }

  Widget _gains() {
    final winners = live.ranking.where((r) => r.gain > 0).toList()..sort((a, b) => b.gain - a.gain);
    if (winners.isEmpty) return Text('Personne n’a trouvé 😅', style: Pb.t(40, color: Pb.muted));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in winners.take(6))
        if (room.player(r.pid) case final p?)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              PbAvatar(size: 56, emoji: p.emoji, color: p.color, photoPath: p.photo),
              const SizedBox(width: 14),
              Expanded(child: Text(p.name, style: Pb.t(36, weight: 600))),
              Text('+${Pb.pts(r.gain)}', style: Pb.t(40, weight: 700, color: Pb.green)),
            ]),
          ),
    ]);
  }
}

/// Dessin à deviner sur le téléphone : on dessine, ou on devine
class DsnPlay extends StatefulWidget {
  const DsnPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<DsnPlay> createState() => _DsnPlayState();
}

class _DsnPlayState extends State<DsnPlay> {
  int _color = 0;
  int _width = drawWidths[1];
  final _guess = TextEditingController();
  final _focus = FocusNode();
  final List<String> _mine = []; // mes propositions de ce tour
  int _turn = -1;

  Map<String, dynamic> get live => widget.live;
  Map<String, dynamic>? get you => widget.you;

  void _g(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': m});

  @override
  void didUpdateWidget(DsnPlay old) {
    super.didUpdateWidget(old);
    if (live.i('turn') != _turn) {
      _turn = live.i('turn');
      _mine.clear();
      _guess.clear();
    }
  }

  @override
  void dispose() {
    _guess.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _sendGuess() {
    final t = _guess.text.trim();
    if (t.isEmpty) return;
    _g({'t': 'dsn_guess', 'text': t});
    setState(() {
      _mine.insert(0, t);
      if (_mine.length > 4) _mine.removeLast();
    });
    _guess.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'draw' || ph == 'reveal') DrawBoard.instance.ensure(live.i('turn', -1), live.i('strokes'));
    final drawer = you.yb('drawer');
    final dName = widget.room.player(live.s('drawer') ?? '')?.name ?? '?';
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🎨', title: 'Dessin à deviner', sub: 'Chacun son tour au crayon !'),
      'choose' => drawer ? _choose() : PhoneCenter(emoji: '⏳', title: '$dName choisit un mot…'),
      'draw' => drawer ? _pad() : _guessView(),
      'reveal' => PhoneCenter(
          emoji: (you.yi('gain') ?? 0) > 0 ? '🎉' : '🖼️',
          title: 'C’était « ${live.s('word') ?? ''} »',
          color: Pb.yellow,
          extra: (you.yi('gain') ?? 0) > 0 ? Text('+${Pb.pts(you.yi('gain')!)}', style: Pb.t(46, weight: 700, color: Pb.green)) : null,
          sub: '${Pb.pts(you.yi('score') ?? 0)} points au total'),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('turn')}-$drawer', isHost: widget.isHost, phase: ph, send: widget.send, child: body);
  }

  Widget _choose() {
    final choices = [for (final c in (you?['choices'] as List?) ?? const []) c as String];
    return ListView(padding: const EdgeInsets.fromLTRB(20, 50, 20, 20), children: [
      Text('À toi de dessiner ! ✏️', textAlign: TextAlign.center, style: Pb.t(28, weight: 700)),
      const SizedBox(height: 6),
      Text('Choisis ton mot', textAlign: TextAlign.center, style: Pb.t(18, color: Pb.muted)),
      const SizedBox(height: 10),
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 20),
      for (var i = 0; i < choices.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Pb.answerColors[i % 4], minimumSize: const Size.fromHeight(72)),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _g({'t': 'dsn_choose', 'i': i});
            },
            child: Text(choices[i], style: Pb.t(26, weight: 700, color: Colors.white)),
          ),
        ),
    ]);
  }

  Widget _pad() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 40, 12, 8),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Dessine : ', style: Pb.t(18, color: Pb.muted)),
              TextSpan(text: you.ys('word') ?? '', style: Pb.t(24, weight: 700, color: Pb.yellow)),
            ])),
          ),
          SizedBox(width: 90, child: TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8)),
        ]),
        const SizedBox(height: 8),
        DrawPad(color: _color, width: _width, send: _g),
        const SizedBox(height: 10),
        // Couleurs
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < drawColors.length; i++)
            GestureDetector(
              onTap: () => setState(() => _color = i),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: drawColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: _color == i ? Pb.pink : Colors.white24, width: _color == i ? 4 : 1),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final w in drawWidths)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _width = w),
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _width == w ? Pb.cardHi : Pb.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _width == w ? Pb.pink : Colors.transparent, width: 2),
                  ),
                  child: Container(width: 6.0 + w / 1.4, height: 6.0 + w / 1.4, decoration: BoxDecoration(color: drawColors[_color] == Colors.white ? Colors.white : drawColors[_color], shape: BoxShape.circle)),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Annuler',
            onPressed: () {
              DrawBoard.instance.localUndo();
              _g({'t': 'drw_undo'});
            },
            icon: const Icon(Icons.undo_rounded, color: Pb.text),
          ),
          IconButton(
            tooltip: 'Tout effacer',
            onPressed: () {
              DrawBoard.instance.localClear();
              _g({'t': 'drw_clear'});
            },
            icon: const Icon(Icons.delete_outline_rounded, color: Pb.text),
          ),
        ]),
      ]),
    );
  }

  Widget _guessView() {
    final found = you.yb('found');
    return ListView(padding: const EdgeInsets.fromLTRB(14, 40, 14, 14), children: [
      Row(children: [
        Expanded(child: Text('${widget.room.player(live.s('drawer') ?? '')?.name ?? '?'} dessine…', style: Pb.t(17, color: Pb.muted))),
        SizedBox(width: 90, child: TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8)),
      ]),
      const SizedBox(height: 8),
      const DrawView(radius: 18),
      const SizedBox(height: 14),
      wordMask(found ? you.ys('word') : live.s('mask'), 24, color: found ? Pb.green : Pb.text),
      const SizedBox(height: 16),
      if (found)
        Text('Bravo, tu as trouvé ! 🎉', textAlign: TextAlign.center, style: Pb.t(22, weight: 700, color: Pb.green))
      else ...[
        Row(children: [
          Expanded(
            child: TextField(
              controller: _guess,
              focusNode: _focus,
              maxLength: 30,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendGuess(),
              style: Pb.t(20, weight: 600),
              decoration: const InputDecoration(hintText: 'Ta proposition…', counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _sendGuess, icon: const Icon(Icons.send_rounded), style: IconButton.styleFrom(backgroundColor: Pb.pink)),
        ]),
        const SizedBox(height: 8),
        for (final m in _mine) Text('✗ $m', style: Pb.t(16, color: Pb.muted)),
      ],
    ]);
  }
}
