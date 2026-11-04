import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import '../widgets/fireworks.dart';
import 'common_ui.dart';

const _green = Color(0xFF3DAA3D);
const _red = Color(0xFFE53935);
const _ink = Color(0xFF111111);

/// Couleur d'une boule selon sa dizaine
Color lotoBallColor(int n) => const [
      Color(0xFFE53935), Color(0xFFFF8A3D), Color(0xFFF5C318), Color(0xFF3DAA3D), Color(0xFF2EC4B6),
      Color(0xFF2D7FE0), Color(0xFF7B5CFF), Color(0xFFC86BFF), Color(0xFFFF4FA3),
    ][(n >= 90 ? 8 : n ~/ 10)];

/// Une boule de loto
class LotoBall extends StatelessWidget {
  const LotoBall({super.key, required this.n, required this.size});
  final int n;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = lotoBallColor(n);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-.35, -.4), colors: [Color.lerp(c, Colors.white, .45)!, c, Color.lerp(c, Colors.black, .35)!], stops: const [0, .55, 1]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: size * .12, offset: Offset(0, size * .06))],
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * .58,
        height: size * .58,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Text('$n', style: Pb.t(size * .3, weight: 700, color: _ink, height: 1)),
      ),
    );
  }
}

/// Un carton : 3 lignes × 9 colonnes, cases vides vertes (comme un carton papier)
class LotoCarton extends StatelessWidget {
  const LotoCarton({super.key, required this.grid, required this.marks, this.onTap, this.width = 358, this.tint = _green});
  final List<List<int>> grid;
  final Set<int> marks;
  final ValueChanged<int>? onTap;
  final double width;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final cw = (width - 6) / 9;
    final ch = cw * 1.32;
    return Container(
      width: width,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomRight: Radius.circular(18), topRight: Radius.circular(4), bottomLeft: Radius.circular(4)),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomRight: Radius.circular(15), topRight: Radius.circular(2), bottomLeft: Radius.circular(2)),
        child: Column(children: [
          for (var r = 0; r < 3; r++)
            Row(children: [
              for (var c = 0; c < 9; c++) _cell(grid[r][c], cw, ch, r, c),
            ]),
        ]),
      ),
    );
  }

  Widget _cell(int n, double w, double h, int r, int c) {
    final border = Border(
      right: c < 8 ? const BorderSide(color: _red, width: 1.2) : BorderSide.none,
      bottom: r < 2 ? const BorderSide(color: _red, width: 1.2) : BorderSide.none,
    );
    if (n == 0) return Container(width: w, height: h, decoration: BoxDecoration(color: tint, border: border));
    final marked = marks.contains(n);
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(n),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: Colors.white, border: border),
        child: Stack(alignment: Alignment.center, children: [
          FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text('$n', style: Pb.t(h * .56, weight: 700, color: _ink, height: 1)),
            ),
          ),
          // Le jeton posé sur le numéro
          AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: marked ? 1 : 0,
            child: Container(
              width: w * .86,
              height: w * .86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Pb.pink.withValues(alpha: .62),
                border: Border.all(color: Pb.pink, width: 2.5),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

String _prizeShout(String? id) => switch (id) { 'quine' => 'QUINE !', 'double' => 'DOUBLE QUINE !', 'plein' => 'CARTON PLEIN !', _ => '' };

// =================================================================== TV

class LotoTv extends StatelessWidget {
  const LotoTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    if (ph == 'podium') return TvPodium(room: room, live: live);
    if (ph == 'intro') {
      return TvIntro(
        emoji: '🎱',
        title: 'Loto',
        sub: 'Quine, double quine, carton plein !',
        rules: [
          'La TV tire les boules de 1 à 90. Ton carton est sur ton téléphone.',
          live['auto'] == true
              ? 'Marquage automatique : les numéros se cochent tout seuls.'
              : 'Touche tes numéros pour poser un jeton, puis appuie sur « Quine ! » au bon moment. Faux = 5 s de pénalité.',
          'Quine : une ligne (300). Double quine : deux lignes (500). Carton plein : tout le carton (1000).',
        ],
        live: live,
      );
    }
    final drawn = {for (final n in (live['drawn'] as List? ?? const [])) (n as num).toInt()};
    final last = (live['last'] as num?)?.toInt();
    final prize = live['prize'] as Map?;
    final winners = [for (final w in (live['winners'] as List? ?? const [])) w as Map];
    final near = [for (final n in (live['near'] as List? ?? const [])) n as Map];
    final ev = live['event'] as Map?;
    final win = ph == 'win' && ev?['k'] == 'win';

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(70, 44, 70, 40),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // La boule tirée
        SizedBox(
          width: 560,
          child: Column(children: [
            Text('Boule ${drawn.length} / 90', style: Pb.t(34, weight: 600, color: Pb.muted)),
            const SizedBox(height: 26),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
              child: last == null ? const SizedBox(width: 400, height: 400) : LotoBall(key: ValueKey(last), n: last, size: 400),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: Text(live.s('nick') == null ? '' : '« ${live.s('nick')} »', style: Pb.t(42, weight: 600, color: Pb.yellow)),
            ),
            const SizedBox(height: 14),
            if (prize != null)
              TvChip(text: 'On joue : ${prize['title']} (${prize['points']} pts)', bg: Pb.pink, size: 38),
            const SizedBox(height: 22),
            // Dernières boules
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final n in (live['drawn'] as List? ?? const []).reversed.skip(1).take(5))
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: LotoBall(n: (n as num).toInt(), size: 82)),
            ]),
          ]),
        ),
        const SizedBox(width: 60),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Le tableau des 90 numéros
            for (var r = 0; r < 9; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  for (var c = 0; c < 10; c++) ...[
                    if (c > 0) const SizedBox(width: 8),
                    Expanded(child: _boardCell(r * 10 + c + 1, drawn.contains(r * 10 + c + 1), r * 10 + c + 1 == last)),
                  ],
                ]),
              ),
            const SizedBox(height: 14),
            if (ph == 'draw') TimeBar(endsIn: live.endsIn, duration: live.duration, height: 10),
            const SizedBox(height: 18),
            // Qui s'approche, et les gagnants
            Wrap(spacing: 18, runSpacing: 12, children: [
              for (final w in winners)
                for (final pid in [for (final p in (w['pids'] as List)) p as String])
                  if (room.player(pid) case final p?)
                    _chip(p, '🏆 ${w['title']}', Pb.yellow),
              for (final n in near)
                if (room.player(n['pid'] as String) case final p?)
                  _chip(p, n['miss'] == 1 ? 'attend 1 numéro !' : 'en attend 2', n['miss'] == 1 ? Pb.red : Pb.muted),
              if (ev?['k'] == 'wrong')
                if (room.player(ev!['pid'] as String) case final p?) _chip(p, '😅 s’est trompé !', Pb.red),
            ]),
          ]),
        ),
      ]),
    );
    if (!win) return content;
    final pids = [for (final p in (ev!['pids'] as List? ?? const [])) p as String];
    return Stack(children: [
      Opacity(opacity: .25, child: content),
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_prizeShout(ev['prize'] as String?), style: Pb.t(150, weight: 700, color: Pb.yellow)),
          const SizedBox(height: 24),
          Wrap(spacing: 40, children: [
            for (final pid in pids)
              if (room.player(pid) case final p?)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  PbAvatar(size: 190, emoji: p.emoji, color: p.color, photoPath: p.photo),
                  const SizedBox(height: 12),
                  Text(p.name, style: Pb.t(60, weight: 700)),
                ]),
          ]),
        ]),
      ),
      const Positioned.fill(child: Fireworks()),
    ]);
  }

  Widget _boardCell(int n, bool on, bool last) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? lotoBallColor(n) : Pb.card.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
        border: last ? Border.all(color: Colors.white, width: 5) : null,
      ),
      child: Text('$n', style: Pb.t(32, weight: 700, color: on ? Colors.white : Pb.muted.withValues(alpha: .5))),
    );
  }

  Widget _chip(PlayerView p, String text, Color c) => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
        decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PbAvatar(size: 46, emoji: p.emoji, color: p.color, photoPath: p.photo),
          const SizedBox(width: 12),
          Text('${p.name} ', style: Pb.t(28, weight: 700)),
          Text(text, style: Pb.t(28, weight: 600, color: c)),
        ]),
      );
}

// =================================================================== téléphone

class LotoPlay extends StatefulWidget {
  const LotoPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final String? myPid;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<LotoPlay> createState() => _LotoPlayState();
}

class _LotoPlayState extends State<LotoPlay> {
  // Blocage après un faux « Quine ! » : compté sur le téléphone
  DateTime _lockedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didUpdateWidget(covariant LotoPlay old) {
    super.didUpdateWidget(old);
    final ms = widget.you.yi('lockedFor') ?? 0;
    if (ms > 0) _lockedUntil = DateTime.now().add(Duration(milliseconds: ms));
  }

  void _g(Map<String, dynamic> m) => widget.send({'t': 'game_msg', 'm': m});

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => PhoneCenter(
          emoji: '🎱',
          title: 'Loto',
          sub: live['auto'] == true ? 'Les numéros se cochent tout seuls. Bonne chance !' : 'Touche tes numéros quand ils sortent, puis annonce « Quine ! »',
          extra: _cartons(interactive: false),
        ),
      'podium' => phoneRank(widget.you),
      _ => _game(),
    };
    return PhoneGameFrame(stepKey: ph == 'podium' || ph == 'intro' ? ph : 'game', isHost: widget.isHost, phase: ph, send: widget.send, child: body);
  }

  Widget _cartons({required bool interactive}) {
    final cards = [for (final g in (widget.you?['cards'] as List? ?? const [])) [for (final r in g as List) [for (final n in r as List) (n as num).toInt()]]];
    final marks = {for (final n in (widget.you?['marks'] as List? ?? const [])) (n as num).toInt()};
    final auto = widget.live['auto'] == true;
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth.clamp(200.0, 420.0) : 358.0;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final (i, g) in cards.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          LotoCarton(
            grid: g,
            marks: marks,
            width: w,
            tint: i == 0 ? _green : const Color(0xFF2D7FE0),
            onTap: interactive && !auto
                ? (n) {
                    HapticFeedback.selectionClick();
                    _g({'t': 'loto_mark', 'n': n});
                  }
                : null,
          ),
        ],
      ]);
    });
  }

  Widget _game() {
    final live = widget.live;
    final last = (live['last'] as num?)?.toInt();
    final prize = live['prize'] as Map?;
    final auto = live['auto'] == true;
    final ev = live['event'] as Map?;
    final win = live.phase == 'win' && ev?['k'] == 'win';
    final winners = win ? [for (final p in (ev!['pids'] as List? ?? const [])) p as String] : const <String>[];
    final iWon = winners.contains(widget.myPid);
    final recent = [for (final n in (live['drawn'] as List? ?? const []).reversed.skip(1).take(4)) (n as num).toInt()];

    final page = Padding(
      padding: const EdgeInsets.fromLTRB(14, 44, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (last != null) LotoBall(n: last, size: 84) else const SizedBox(width: 84, height: 84),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (live.s('nick') != null) Text('« ${live.s('nick')} »', style: Pb.t(16, weight: 600, color: Pb.yellow)),
              if (prize != null) Text('On joue : ${prize['title']}', style: Pb.t(20, weight: 700)),
              const SizedBox(height: 6),
              Row(children: [for (final n in recent) Padding(padding: const EdgeInsets.only(right: 6), child: LotoBall(n: n, size: 34))]),
            ]),
          ),
        ]),
        if (live.phase == 'draw') ...[const SizedBox(height: 8), TimeBar(endsIn: live.endsIn, duration: live.duration, height: 5)],
        const SizedBox(height: 12),
        if (win)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Pb.yellow, borderRadius: BorderRadius.circular(16)),
            child: Text(
              iWon ? '${_prizeShout(ev!['prize'] as String?)} Bravo !' : '${_prizeShout(ev!['prize'] as String?)} pour ${[for (final p in winners) widget.room.player(p)?.name ?? '?'].join(', ')}',
              textAlign: TextAlign.center,
              style: Pb.t(20, weight: 700, color: Pb.bg),
            ),
          ),
        Expanded(child: SingleChildScrollView(child: _cartons(interactive: true))),
        const SizedBox(height: 10),
        if (!auto && prize != null) _claimButton(prize['id'] as String?),
        if (auto) Text('Marquage automatique', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.muted)),
      ]),
    );
    if (!iWon) return page;
    return Stack(children: [page, const Positioned.fill(child: IgnorePointer(child: Fireworks(seconds: 4)))]);
  }

  Widget _claimButton(String? prizeId) {
    final left = _lockedUntil.difference(DateTime.now());
    if (left > Duration.zero) {
      // Se réaffiche tout seul à la fin du blocage
      Future.delayed(left, () {
        if (mounted) setState(() {});
      });
      return SizedBox(
        height: 70,
        child: FilledButton(onPressed: null, child: Text('Faux ! Attends ${left.inSeconds + 1} s', style: Pb.t(22, weight: 700))),
      );
    }
    return SizedBox(
      height: 70,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Pb.yellow, foregroundColor: Pb.bg),
        onPressed: () {
          HapticFeedback.heavyImpact();
          _g({'t': 'loto_claim'});
        },
        child: Text(_prizeShout(prizeId), style: Pb.t(28, weight: 700, color: Pb.bg)),
      ),
    );
  }
}
