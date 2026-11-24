import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

const _vrai = Color(0xFF2BB36B);
const _bluff = Pb.pink;
const _vraiDark = Color(0xFF1D7A4A);
const _bluffDark = Color(0xFFA3226A);

String _word(String? v) => v == 'v' ? 'VRAI' : 'BLUFF';

/// Vrai ou Bluff sur la TV
class BlfTv extends StatelessWidget {
  const BlfTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🤥',
          title: 'Vrai ou Bluff',
          sub: 'Anecdotes vraies… ou pas !',
          rules: const [
            'Ton téléphone te dit en secret : raconte un fait VRAI sur toi, ou invente un BLUFF.',
            'Chacun défend son anecdote à voix haute, les autres votent Vrai ou Bluff.',
            'Bon vote : +500 (+ rapidité). L’auteur gagne 100 par joueur trompé !',
          ],
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
          const Text('🤥', style: TextStyle(fontSize: 150)),
          Text('Écrivez votre anecdote !', style: Pb.t(90, weight: 700)),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(style: Pb.t(44, color: Pb.muted), children: [
              const TextSpan(text: 'Regardez votre téléphone en cachette : un fait '),
              TextSpan(text: 'vrai', style: Pb.t(44, weight: 700, color: Pb.green)),
              const TextSpan(text: ' ou un '),
              TextSpan(text: 'bluff', style: Pb.t(44, weight: 700, color: _bluff)),
              const TextSpan(text: ' ?'),
            ]),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
          const SizedBox(height: 26),
          SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('done').toSet(), label: 'ont écrit')),
        ]),
      );

  Widget _round() {
    final reveal = live.phase == 'reveal';
    final author = room.player(live.s('author') ?? '');
    final voted = live.pids('answered').where((p) => p != live.s('author')).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Anecdote', index: live.i('index'), count: live.i('count'), live: reveal ? null : live),
        const SizedBox(height: 10),
        SizedBox(
          height: reveal ? 380 : 560,
          child: Stack(clipBehavior: Clip.none, children: [
            Row(children: [
              SizedBox(
                width: reveal ? 260 : 330,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (author != null) PbAvatar(size: reveal ? 180 : 240, emoji: author.emoji, color: author.color, photoPath: author.photo),
                  const SizedBox(height: 14),
                  Text(author?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(reveal ? 46 : 56, weight: 700)),
                ]),
              ),
              const SizedBox(width: 40),
              Expanded(child: Padding(padding: EdgeInsets.only(right: reveal ? 470 : 0), child: _Bubble(text: live.s('text') ?? '', theme: live.s('theme'), small: reveal))),
            ]),
            if (reveal) Positioned(right: 10, top: 90, child: _Stamp(truth: live.s('truth'))),
          ]),
        ),
        const SizedBox(height: 20),
        Expanded(child: reveal ? _results(author) : _voting(author, voted)),
      ]),
    );
  }

  Widget _voting(PlayerView? author, List<String> voted) => Column(children: [
        Row(children: [
          Text('A voté :  ', style: Pb.t(40, color: Pb.muted)),
          if (voted.isEmpty) Text('personne pour l’instant', style: Pb.t(40, color: Pb.muted)) else TvAvatarRow(room: room, pids: voted, size: 70),
          const Spacer(),
          Text('🎤 ${author?.name ?? '?'}, défends ton histoire !', style: Pb.t(44, weight: 600, color: Pb.yellow)),
        ]),
        const Spacer(),
        Text('Vrai ou Bluff ? Votez sur votre téléphone, vous pouvez poser des questions !', style: Pb.t(40, color: Pb.text)),
        const SizedBox(height: 18),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
      ]);

  Widget _results(PlayerView? author) {
    final truth = live.s('truth');
    final picks = {for (final e in ((live['picks'] as Map?) ?? const {}).entries) e.key as String: e.value as String};
    final gains = {for (final r in live.ranking) r.pid: r.gain};
    final fooled = picks.values.where((v) => v != truth).length;
    Widget col(String v) {
      final win = v == truth;
      final who = [for (final e in picks.entries) if (e.value == v) e.key];
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
          decoration: BoxDecoration(
            color: Pb.card,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: win ? Pb.green : Colors.transparent, width: 6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(v == 'v' ? '✅ Vrai' : '🤥 Bluff', style: Pb.t(48, weight: 700)),
              const Spacer(),
            ]),
            const SizedBox(height: 14),
            if (who.isEmpty)
              Text('personne', style: Pb.t(36, color: Pb.muted))
            else
              Wrap(spacing: 18, runSpacing: 12, children: [
                for (final pid in who)
                  if (room.player(pid) case final p?)
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 22, 6),
                      decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(60)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        PbAvatar(size: 64, emoji: p.emoji, color: p.color, photoPath: p.photo),
                        const SizedBox(width: 12),
                        Text(p.name, style: Pb.t(34, weight: 600)),
                        if (win && (gains[pid] ?? 0) > 0) ...[const SizedBox(width: 12), Text('+${Pb.pts(gains[pid]!)}', style: Pb.t(34, weight: 700, color: Pb.green))],
                      ]),
                    ),
              ]),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        fooled == 0 ? '😅 ${author?.name ?? '?'} n’a trompé personne' : '😎 ${author?.name ?? '?'} : +${Pb.pts(fooled * 100)} ($fooled joueur${fooled > 1 ? 's' : ''} trompé${fooled > 1 ? 's' : ''})',
        style: Pb.t(42, weight: 600, color: Pb.yellow),
      ),
      const SizedBox(height: 18),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [col('v'), const SizedBox(width: 30), col('b')])),
    ]);
  }
}

/// La bulle de l'anecdote (texte qui rétrécit s'il est long)
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.theme, required this.small});
  final String text;
  final String? theme;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
      Positioned(left: -34, child: CustomPaint(size: const Size(40, 60), painter: _Tail())),
      Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: small ? 44 : 60, vertical: small ? 30 : 44),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(56), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 12))]),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (theme != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF9B5CFF), borderRadius: BorderRadius.circular(40)),
              child: Text(theme!, style: Pb.t(small ? 26 : 32, weight: 600, color: Colors.white)),
            ),
            const SizedBox(height: 16),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: small ? 220 : 340),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: small ? 860 : 1100,
                child: Text(text, style: Pb.t(text.length > 90 ? 52 : 64, weight: 600, color: const Color(0xFF22163F), height: 1.25)),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Tail extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawPath(Path()..moveTo(s.width, 0)..lineTo(0, s.height / 2)..lineTo(s.width, s.height)..close(), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Le tampon « VRAI ! » / « BLUFF ! » qui tombe
class _Stamp extends StatelessWidget {
  const _Stamp({required this.truth});
  final String? truth;

  @override
  Widget build(BuildContext context) {
    final c = truth == 'v' ? Pb.green : _bluff;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 2.4, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(opacity: (2.4 - v).clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
      child: Transform.rotate(
        angle: -12 * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
          decoration: BoxDecoration(color: const Color(0x55000000), border: Border.all(color: c, width: 14), borderRadius: BorderRadius.circular(28)),
          child: Text('${_word(truth)} !', style: Pb.t(130, weight: 700, color: c)),
        ),
      ),
    );
  }
}

/// Vrai ou Bluff sur le téléphone
class BlfPlay extends StatelessWidget {
  const BlfPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
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
      'intro' => const PhoneCenter(emoji: '🤥', title: 'Vrai ou Bluff', sub: 'Ton téléphone va te dire en secret si tu dois dire la vérité ou bluffer. Ne montre ton écran à personne !'),
      'write' => _BlfWrite(key: const ValueKey('write'), you: you, live: live, send: send),
      'ask' => _ask(),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(
      stepKey: ph == 'write' ? 'write' : '$ph-${live.i('index')}',
      isHost: isHost,
      phase: ph,
      send: send,
      hostActions: ph == 'ask' ? const [(label: 'Écarter cette anecdote', icon: Icons.block_rounded, msg: {'t': 'blf_drop'})] : const [],
      child: body,
    );
  }

  Widget _ask() {
    final author = room.player(live.s('author') ?? '');
    if (you.yb('mine')) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎤', style: TextStyle(fontSize: 76)),
            Text('C’est ton anecdote !', textAlign: TextAlign.center, style: Pb.t(28, weight: 700)),
            const SizedBox(height: 8),
            Text('Défends-la à voix haute,\ntu ne votes pas.', textAlign: TextAlign.center, style: Pb.t(17, color: Pb.muted)),
            const SizedBox(height: 18),
            _SecretCard(secret: you.ys('secret'), reminder: true),
            const SizedBox(height: 14),
            Text('${live.pids('answered').length} vote${live.pids('answered').length > 1 ? 's' : ''} pour l’instant', style: Pb.t(16, color: Pb.muted)),
          ]),
        ),
      );
    }
    final picked = you.ys('answer');
    Widget btn(String v) {
      final sel = picked == v, dim = picked != null && !sel;
      return Expanded(
        child: AnimatedScale(
          scale: sel ? 1.03 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            opacity: dim ? .4 : 1,
            duration: const Duration(milliseconds: 150),
            child: Material(
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: v == 'v' ? const [_vraiDark, _vrai] : const [_bluffDark, _bluff]),
                  border: Border.all(color: sel ? Pb.yellow : Colors.transparent, width: 5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    send({'t': 'game_msg', 'm': {'t': 'blf_vote', 'r': live.i('index'), 'v': v}});
                  },
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(v == 'v' ? '✅ VRAI' : '🤥 BLUFF', style: Pb.t(38, weight: 700, color: Colors.white)),
                      Text(v == 'v' ? 'Je le crois !' : 'On me la fait pas', style: Pb.t(15, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${author?.emoji ?? ''} ${author?.name ?? '?'} raconte :', style: Pb.t(14, color: Pb.muted)),
            const SizedBox(height: 4),
            Text(live.s('text') ?? '', maxLines: 6, overflow: TextOverflow.ellipsis, style: Pb.t(17, weight: 600, height: 1.3)),
          ]),
        ),
        const SizedBox(height: 12),
        btn('v'),
        const SizedBox(height: 12),
        btn('b'),
        const SizedBox(height: 10),
        Text(picked == null ? 'Écoute bien, pose des questions…' : 'Tu peux changer d’avis jusqu’à la fin du temps.', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.muted)),
      ]),
    );
  }

  Widget _reveal() {
    final truth = live.s('truth');
    final g = you.yi('gain') ?? 0;
    if (live.s('author') == myPid) {
      final fooled = ((live['picks'] as Map?) ?? const {}).values.where((v) => v != truth).length;
      return PhoneCenter(
        emoji: fooled > 0 ? '😎' : '😅',
        title: fooled > 0 ? '$fooled joueur${fooled > 1 ? 's' : ''} trompé${fooled > 1 ? 's' : ''} !' : 'Personne n’est tombé dans le panneau',
        color: fooled > 0 ? Pb.green : Pb.text,
        extra: g > 0 ? Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)) : null,
        sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
      );
    }
    final voted = ((live['picks'] as Map?) ?? const {})[myPid] as String?;
    return PhoneCenter(
      emoji: voted == null ? '🙈' : (voted == truth ? '🎯' : '😵'),
      title: voted == null ? 'Pas de vote…' : (voted == truth ? 'Bien vu !' : 'Raté…'),
      color: voted == truth ? Pb.green : (voted == null ? Pb.text : Pb.pink),
      extra: g > 0 ? Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)) : Text('C’était ${_word(truth)} !', style: Pb.t(24, weight: 700, color: truth == 'v' ? Pb.green : _bluff)),
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}

/// La consigne secrète
class _SecretCard extends StatelessWidget {
  const _SecretCard({required this.secret, this.reminder = false});
  final String? secret;
  final bool reminder;

  @override
  Widget build(BuildContext context) {
    final v = secret == 'v';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: v ? const [_vraiDark, _vrai] : const [_bluffDark, _bluff]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text(reminder ? 'Pour rappel, c’est :' : '🤫 Rien que pour toi :', style: Pb.t(14, weight: 600, color: Colors.white)),
        Text(reminder ? (v ? 'VRAI' : 'UN BLUFF') : (v ? 'DIS LA VÉRITÉ' : 'BLUFFE !'), style: Pb.t(30, weight: 700, color: Colors.white)),
        if (!reminder) Text(v ? 'Une histoire vraie… mais incroyable' : 'Invente un truc crédible sur toi', style: Pb.t(14, color: Colors.white)),
      ]),
    );
  }
}

/// Écriture de l'anecdote : consigne secrète, sujets d'aide, texte (modifiable jusqu'à la fin)
class _BlfWrite extends StatefulWidget {
  const _BlfWrite({super.key, required this.you, required this.live, required this.send});
  final Map<String, dynamic>? you;
  final Map<String, dynamic> live;
  final void Function(Map<String, dynamic>) send;

  @override
  State<_BlfWrite> createState() => _BlfWriteState();
}

class _BlfWriteState extends State<_BlfWrite> {
  late final _c = TextEditingController(text: widget.you.ys('written') ?? '');
  int? _theme;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String? get _sent => widget.you.ys('written');
  bool get _ok => _c.text.trim().characters.length >= 8;

  void _send() {
    if (!_ok) return;
    HapticFeedback.mediumImpact();
    widget.send({'t': 'game_msg', 'm': {'t': 'blf_write', 'text': _c.text.trim(), if (_theme != null) 'theme': _theme}});
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final themes = [for (final t in (widget.you?['themes'] as List?) ?? const []) t as String];
    final secret = widget.you.ys('secret');
    final sentSame = _sent != null && _sent == _c.text.trim();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 46, 16, 16), children: [
      TimeBar(endsIn: widget.live.endsIn, duration: widget.live.duration, height: 8),
      const SizedBox(height: 12),
      if (secret != null) _SecretCard(secret: secret) else Text('Tu es arrivé en cours : tu voteras pour les autres !', textAlign: TextAlign.center, style: Pb.t(17, color: Pb.muted)),
      if (secret != null) ...[
        const SizedBox(height: 12),
        Text('Une idée de sujet ? (facultatif)', style: Pb.t(14, color: Pb.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (i, t) in themes.indexed)
            ChoiceChip(
              label: Text(t, style: Pb.t(13, weight: 600, color: _theme == i ? Colors.white : Pb.text)),
              selected: _theme == i,
              selectedColor: const Color(0xFF9B5CFF),
              backgroundColor: Pb.card,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (on) => setState(() => _theme = on ? i : null),
            ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _c,
          maxLength: 140,
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          style: Pb.t(17),
          decoration: const InputDecoration(hintText: 'Ex. : J’ai déjà serré la main de Zidane…'),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: _ok && !sentSame ? _send : null,
            style: FilledButton.styleFrom(backgroundColor: Pb.yellow, foregroundColor: Pb.bg),
            child: Text(sentSame ? 'Envoyé ✓' : (_sent != null ? 'Envoyer la nouvelle version' : 'Envoyer 📨'), style: Pb.t(19, weight: 700, color: Pb.bg)),
          ),
        ),
        if (_sent != null) ...[
          const SizedBox(height: 8),
          Text('C’est envoyé ! Tu peux encore la modifier en attendant les autres.', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.green)),
        ],
      ],
    ]);
  }
}
