import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../music.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

// =================================================================== son

/// L'extrait du Blind test (adresse Deezer donnée par le serveur). Joué par la TV, et par
/// les téléphones d'un salon permanent qui ont « Sons sur mon téléphone ».
/// Chargé pendant la phase « load », lancé au début de « ask », continue pendant « reveal ».
class BtAudio {
  BtAudio._();
  static final instance = BtAudio._();

  AudioPlayer? _player;
  String? _key; // manche chargée
  bool _started = false;
  Future<void>? _loading;

  AudioPlayer get _p {
    final p = _player ??= AudioPlayer();
    return p;
  }

  void onRoom(Map<String, dynamic> room, {bool enabled = true}) {
    final live = room['game'] as Map<String, dynamic>?;
    final phase = live?['phase'] as String?;
    final url = live?['audio'] as String?;
    final key = live?['roundKey'] as String?;
    if (!enabled || live?['id'] != 'blindtest' || url == null || key == null || !const {'load', 'ask', 'reveal'}.contains(phase)) {
      stop();
      return;
    }
    if (key != _key) {
      _key = key;
      _started = false;
      final p = _p;
      _loading = () async {
        try {
          await pbMixAudio(p);
          await p.stop();
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setVolume(1);
          await p.setSourceUrl(url);
        } catch (_) {}
      }();
    }
    if ((phase == 'ask' || phase == 'reveal') && !_started) {
      _started = true;
      // Arrivé en cours de route : on se place où en est l'écoute
      final late = phase == 'ask' ? ((live!['duration'] as num? ?? 0) - (live['endsIn'] as num? ?? 0)).toInt() : 0;
      final k = _key;
      unawaited(() async {
        await _loading;
        if (_key != k) return;
        try {
          if (late > 1500) await _p.seek(Duration(milliseconds: late));
          await _p.resume();
        } catch (_) {
          // navigateur : son bloqué tant qu'on n'a pas touché l'écran
        }
      }());
    }
  }

  void stop() {
    if (_key == null) return;
    _key = null;
    _started = false;
    final p = _player;
    if (p != null) unawaited(p.stop().catchError((_) {}));
  }
}

// =================================================================== décor

/// Disque vinyle (tourne pendant l'écoute)
class BtDisc extends StatefulWidget {
  const BtDisc({super.key, required this.size, this.spinning = true});
  final double size;
  final bool spinning;

  @override
  State<BtDisc> createState() => _BtDiscState();
}

class _BtDiscState extends State<BtDisc> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(BtDisc old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) _c.repeat();
    if (!widget.spinning) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  // Le disque est dessiné une seule fois (RepaintBoundary sous la rotation) : chaque image
  // ne fait que le tourner. Avant, il était redessiné 60 fois par seconde (sillons, reflets,
  // ombre floue), trop lourd pour la TV.
  Widget build(BuildContext context) => RepaintBoundary(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 14))]),
          child: RotationTransition(
            turns: _c,
            child: RepaintBoundary(child: CustomPaint(painter: _DiscPainter(), size: Size.square(widget.size))),
          ),
        ),
      );
}

class _DiscPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF16161A));
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * .006)
      ..color = const Color(0xFF2A2A31);
    for (var g = r * .97; g > r * .36; g -= r * .022) {
      canvas.drawCircle(c, g, groove);
    }
    // reflets
    final shine = Paint()
      ..shader = SweepGradient(colors: const [
        Colors.transparent, Color(0x22FFFFFF), Colors.transparent, Colors.transparent, Color(0x18FFFFFF), Colors.transparent,
      ], stops: const [0, .12, .24, .5, .62, .74])
          .createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * .97, shine);
    // étiquette
    final label = Paint()
      ..shader = const SweepGradient(colors: [Pb.pink, Pb.yellow, Pb.cyan, Pb.pink]).createShader(Rect.fromCircle(center: c, radius: r * .33));
    canvas.drawCircle(c, r * .33, label);
    canvas.drawCircle(c, r * .05, Paint()..color = Pb.bg);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Égaliseur qui danse pendant l'écoute
class BtEqualizer extends StatefulWidget {
  const BtEqualizer({super.key, this.bars = 16, this.height = 110, this.barWidth = 22});
  final int bars;
  final double height, barWidth;

  @override
  State<BtEqualizer> createState() => _BtEqualizerState();
}

class _BtEqualizerState extends State<BtEqualizer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size(widget.bars * widget.barWidth * 1.45, widget.height),
          painter: _EqPainter(_c, widget.bars, widget.barWidth),
        ),
      );
}

class _EqPainter extends CustomPainter {
  _EqPainter(this.t, this.bars, this.w) : super(repaint: t);
  final Animation<double> t;
  final int bars;
  final double w;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Pb.pink, Pb.cyan])
          .createShader(Offset.zero & size);
    for (var i = 0; i < bars; i++) {
      final h = size.height * (.18 + .82 * (.5 + .5 * math.sin(t.value * math.pi * 2 * (5 + i % 4) + i * 1.7)).abs());
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * w * 1.45, size.height - h, w, h), Radius.circular(w / 3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqPainter old) => false;
}

/// Pochette de l'album (révélation) ; disque si elle ne charge pas
class BtCover extends StatelessWidget {
  const BtCover({super.key, required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = BtDisc(size: size, spinning: false);
    if (url == null || url!.isEmpty) return fallback;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .6, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .06), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 16))]),
        clipBehavior: Clip.antiAlias,
        child: Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

String _leftTitle(Map<String, dynamic> live) => live.s('leftLabel') == 'film' ? 'Film' : 'Artiste';
String _leftEmoji(Map<String, dynamic> live) => live.s('leftLabel') == 'film' ? '🎬' : '🎤';

// =================================================================== TV

/// Blind test sur la TV
class BtTv extends StatelessWidget {
  const BtTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🎵',
          title: 'Blind test',
          sub: '${live.s('playlist') ?? ''} · ${live.i('count')} extraits',
          rules: const [
            'Un extrait passe : trouve l’artiste (à gauche) et le titre (à droite) sur ton téléphone.',
            'Un seul essai par colonne. Plus tu es rapide, plus tu marques ! Les deux justes : bonus.',
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
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(
          label: 'Musique',
          index: live.i('index'),
          count: live.i('count'),
          live: ph == 'ask' ? live : null,
          extra: TvChip(text: live.s('playlist') ?? '', color: Pb.yellow, size: 36),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(children: [
            SizedBox(
              width: 560,
              child: Center(child: reveal ? BtCover(url: live.s('cover'), size: 520) : BtDisc(size: 520, spinning: ph == 'ask')),
            ),
            const SizedBox(width: 70),
            Expanded(child: reveal ? _answer() : _listen()),
          ]),
        ),
      ]),
    );
  }

  Widget _listen() {
    if (live.phase == 'load') {
      return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Prêts ?', style: Pb.t(96, weight: 700)),
        const SizedBox(height: 12),
        Text('Ouvrez grand vos oreilles… 🎧', style: Pb.t(48, color: Pb.muted)),
      ]);
    }
    final answered = <String, String>{
      for (final e in ((live['answered'] as Map?) ?? const {}).entries) e.key as String: e.value as String,
    };
    final players = room.players.where((p) => p.connected).toList();
    final size = rowAvatar(players.length).clamp(54.0, 80.0);
    final film = live.s('leftLabel') == 'film';
    return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(film ? 'Quel film ? Quel titre ?' : 'Qui chante ? Quel titre ?', style: Pb.t(80, weight: 700, height: 1.05)),
      const SizedBox(height: 10),
      Text('Réponds sur ton téléphone : ${film ? 'film' : 'artiste'} à gauche, titre à droite', style: Pb.t(38, color: Pb.muted)),
      const SizedBox(height: 50),
      const BtEqualizer(),
      const SizedBox(height: 50),
      Text('Ont répondu', style: Pb.t(30, weight: 600, color: Pb.muted)),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 14, children: [
        for (final p in players)
          Stack(clipBehavior: Clip.none, children: [
            PbAvatar(size: size, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !answered.containsKey(p.pid)),
            if ((answered[p.pid] ?? '').isNotEmpty)
              Positioned(
                right: -10,
                bottom: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Pb.bg, borderRadius: BorderRadius.circular(20)),
                  child: Text('${answered[p.pid]!.contains('a') ? _leftEmoji(live) : ''}${answered[p.pid]!.contains('t') ? '🎵' : ''}', style: TextStyle(fontSize: size * .32)),
                ),
              ),
          ]),
      ]),
    ]);
  }

  Widget _answer() {
    final film = live.s('film');
    final picks = (live['picks'] as Map?) ?? const {};
    final ca = live.i('ca'), ct = live.i('ct');
    final rk = {for (final r in live.ranking) r.pid: r};
    final players = room.players.where((p) => p.connected || picks.containsKey(p.pid)).toList()
      ..sort((a, b) => (rk[b.pid]?.gain ?? 0) - (rk[a.pid]?.gain ?? 0));
    Widget card(String k, String v, Color c, [String? sub]) => Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(36, 20, 36, 22),
          decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(30)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.toUpperCase(), style: Pb.t(26, weight: 600, color: Pb.muted)),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: Pb.t(68, weight: 700, color: c, height: 1.1))),
            if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(28, color: Pb.muted)),
          ]),
        );
    final rows = <Widget>[
      for (final p in players)
        Builder(builder: (_) {
          final pk = picks[p.pid] as Map?;
          final okA = pk?['a'] == ca, okT = pk?['t'] == ct;
          final tags = '${okA ? '${_leftEmoji(live)}✓ ' : ''}${okT ? '🎵✓' : ''}';
          final g = rk[p.pid]?.gain ?? 0;
          return Row(children: [
            PbAvatar(size: 54, emoji: p.emoji, color: p.color, photoPath: p.photo),
            const SizedBox(width: 12),
            Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(32, weight: 600))),
            const SizedBox(width: 10),
            Text(pk == null ? '—' : (tags.isEmpty ? '✗' : tags), style: Pb.t(26, color: Pb.muted)),
            const Spacer(),
            Text(g > 0 ? '+${Pb.pts(g)}' : '0', style: Pb.t(32, weight: 700, color: g > 0 ? Pb.green : Pb.muted)),
          ]);
        }),
    ];
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      card(film != null ? 'Film' : 'Artiste', film ?? live.s('artist') ?? '', Pb.text, film != null ? live.s('artist') : null),
      const SizedBox(height: 18),
      card('Titre', live.s('title') ?? '', Pb.yellow, film == null ? live.s('album') : null),
      const SizedBox(height: 26),
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1100,
            child: Wrap(spacing: 40, runSpacing: 12, children: [for (final r in rows) SizedBox(width: 530, height: 60, child: r)]),
          ),
        ),
      ),
    ]);
  }
}

// =================================================================== téléphone

/// Blind test sur le téléphone : artiste à gauche, titre à droite
class BtPlay extends StatelessWidget {
  const BtPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🎵', title: 'Blind test', sub: 'Écoute la TV : trouve l’artiste à gauche et le titre à droite. Un seul essai par colonne !'),
      'load' => const PhoneCenter(emoji: '🎧', title: 'Prêt ?', sub: 'L’extrait arrive…'),
      'ask' || 'reveal' => _columns(context),
      'podium' => _podium(),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '${ph == 'reveal' ? 'ask' : ph}-${live.i('index')}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _columns(BuildContext context) {
    final reveal = live.phase == 'reveal';
    final pa = you.yi('pa'), pt = you.yi('pt');
    final film = live.s('leftLabel') == 'film';
    String status;
    Color statusColor = Pb.muted;
    if (reveal) {
      final g = you.yi('gain') ?? 0;
      final okA = pa != null && pa == live.i('ca'), okT = pt != null && pt == live.i('ct');
      status = '${film ? 'Film' : 'Artiste'} ${okA ? '✓' : '✗'} · Titre ${okT ? '✓' : '✗'}   ${g > 0 ? '+${Pb.pts(g)} pts' : '0 pt cette fois'}';
      statusColor = g > 0 ? Pb.green : Pb.text;
    } else if (pa != null && pt != null) {
      status = 'C’est envoyé ! On attend les autres…';
    } else if (pa != null) {
      status = '${film ? 'Film' : 'Artiste'} choisi. Et le titre ?';
    } else if (pt != null) {
      status = 'Titre choisi. Et ${film ? 'le film' : 'l’artiste'} ?';
    } else {
      status = 'Un seul essai par colonne 😉';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 44, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!reveal) TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8) else const SizedBox(height: 8),
        const SizedBox(height: 10),
        Text(
          reveal ? (live.s('title') ?? '') : '🎧 Qui ? Quoi ?',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Pb.t(22, weight: 700, color: reveal ? Pb.yellow : Pb.text),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _col('a', '${_leftEmoji(live)} ${_leftTitle(live)}', film ? 'quel film ?' : 'qui chante ?', live.pids('artists'), pa, live.i('ca'), reveal)),
            const SizedBox(width: 10),
            Expanded(child: _col('t', '🎵 Titre', 'la chanson', live.pids('titles'), pt, live.i('ct'), reveal)),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(14)),
          child: Text(status, textAlign: TextAlign.center, style: Pb.t(15, weight: 600, color: statusColor)),
        ),
      ]),
    );
  }

  Widget _col(String k, String title, String sub, List<String> choices, int? picked, int correct, bool reveal) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(title, style: Pb.t(15, weight: 700)),
          Text(sub, style: Pb.t(11, color: Pb.muted)),
        ]),
      ),
      for (var i = 0; i < choices.length; i++) ...[
        const SizedBox(height: 8),
        Expanded(child: _button(k, i, choices[i], picked, correct, reveal)),
      ],
    ]);
  }

  Widget _button(String k, int i, String label, int? picked, int correct, bool reveal) {
    final color = Pb.answerColors[i % 4];
    final dark = i >= 2; // jaune et vert : texte foncé
    double opacity = 1;
    Border? border;
    if (reveal) {
      if (i == correct) {
        border = Border.all(color: Pb.green, width: 4);
      } else if (i == picked) {
        border = Border.all(color: Colors.white, width: 3);
        opacity = .55;
      } else {
        opacity = .25;
      }
    } else if (picked != null) {
      if (i == picked) {
        border = Border.all(color: Colors.white, width: 4);
      } else {
        opacity = .28;
      }
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: opacity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: reveal || picked != null
              ? null
              : () {
                  HapticFeedback.heavyImpact();
                  send({'t': 'game_msg', 'm': {'t': 'bt_pick', 'r': live.i('index'), 'k': k, 'choice': i}});
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: border),
            alignment: Alignment.center,
            child: Row(children: [
              if (reveal && i == correct) const Padding(padding: EdgeInsets.only(right: 4), child: Text('✅', style: TextStyle(fontSize: 14))),
              if (reveal && i == picked && i != correct) const Padding(padding: EdgeInsets.only(right: 4), child: Text('❌', style: TextStyle(fontSize: 14))),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Pb.t(label.length > 26 ? 13 : 15, weight: 700, color: dark ? const Color(0xFF231400) : Colors.white, height: 1.12),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _podium() {
    final f = (you?['found'] as Map?) ?? const {};
    final n = (live['played'] as num?)?.toInt() ?? live.i('count');
    Widget line(String k, Object? v) => Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [Text(k, style: Pb.t(16)), const Spacer(), Text('${v ?? 0} / $n', style: Pb.t(16, weight: 700))]),
        );
    return Column(children: [
      Expanded(child: phoneRank(you)),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(children: [line('🎤 Artistes trouvés', f['a']), line('🎵 Titres trouvés', f['t'])]),
      ),
    ]);
  }
}
