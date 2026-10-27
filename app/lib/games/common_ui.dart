import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';

/// Lecture tolérante de l'état envoyé par le serveur
extension Live on Map<String, dynamic> {
  String get phase => this['phase'] as String? ?? '';
  int i(String k, [int d = 0]) => (this[k] as num?)?.toInt() ?? d;
  String? s(String k) => this[k] as String?;
  List<String> pids(String k) => [for (final x in (this[k] as List?) ?? const []) x as String];
  List<Map<String, dynamic>> maps(String k) => [for (final x in (this[k] as List?) ?? const []) x as Map<String, dynamic>];
  int get endsIn => i('endsIn');
  int get duration => i('duration', 1);
  List<GameRank> get ranking => [for (final r in maps('ranking')) GameRank.fromJson(r)];
}

class GameRank {
  GameRank.fromJson(Map<String, dynamic> j)
      : pid = j['pid'] as String,
        score = (j['score'] as num).toInt(),
        rank = (j['rank'] as num).toInt(),
        gain = (j['gain'] as num?)?.toInt() ?? 0;
  final String pid;
  final int score;
  final int rank;
  final int gain;
}

/// Ce que chaque téléphone reçoit en plus (« you »)
extension You on Map<String, dynamic>? {
  int? yi(String k) => (this?[k] as num?)?.toInt();
  String? ys(String k) => this?[k] as String?;
  bool yb(String k) => this?[k] == true;
}

// =================================================================== TV

/// Écran d'introduction d'un jeu sur la TV
class TvIntro extends StatelessWidget {
  const TvIntro({super.key, required this.emoji, required this.title, required this.sub, required this.rules, required this.live});
  final String emoji, title, sub;
  final List<String> rules;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 160)),
        Text(title, style: Pb.t(104, weight: 700)),
        const SizedBox(height: 10),
        Text(sub, style: Pb.t(50, weight: 600, color: Pb.yellow)),
        const SizedBox(height: 44),
        for (final r in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(r, textAlign: TextAlign.center, style: Pb.t(40, color: Pb.muted, height: 1.25)),
          ),
        const SizedBox(height: 40),
        TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 120),
      ]),
    );
  }
}

/// En-tête commun : « Manche 2 / 5 » + chrono
class TvHeader extends StatelessWidget {
  const TvHeader({super.key, required this.label, required this.index, required this.count, this.live, this.extra});
  final String label;
  final int index, count;
  final Map<String, dynamic>? live;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label ${index + 1}', style: Pb.t(44, weight: 700)),
      Text(' / $count', style: Pb.t(44, color: Pb.muted)),
      if (extra != null) ...[const SizedBox(width: 28), extra!],
      const Spacer(),
      if (live != null) TimeCircle(endsIn: live!.endsIn, duration: live!.duration, size: 104),
    ]);
  }
}

/// Rangée d'avatars : qui a déjà joué (coche) / qui attend (grisé)
class TvWhoDone extends StatelessWidget {
  const TvWhoDone({super.key, required this.room, required this.done, this.label = 'ont répondu', this.exclude});
  final RoomView room;
  final Set<String> done;
  final String label;
  final String? exclude;

  @override
  Widget build(BuildContext context) {
    final players = room.players.where((p) => p.connected && p.pid != exclude).toList();
    final n = players.where((p) => done.contains(p.pid)).length;
    return Row(children: [
      Text('$n/${players.length} $label', style: Pb.t(34, weight: 600, color: Pb.muted)),
      const SizedBox(width: 26),
      for (final p in players)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Stack(clipBehavior: Clip.none, children: [
            PbAvatar(size: 76, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !done.contains(p.pid)),
            if (done.contains(p.pid)) const Positioned(right: -6, bottom: -6, child: Text('✔️', style: TextStyle(fontSize: 30))),
          ]),
        ),
    ]);
  }
}

/// Gains de la manche (+points) en bas d'écran
class TvGains extends StatelessWidget {
  const TvGains({super.key, required this.room, required this.ranking, this.empty = 'Personne ne marque cette fois !'});
  final RoomView room;
  final List<GameRank> ranking;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final winners = ranking.where((r) => r.gain > 0).toList()..sort((a, b) => b.gain - a.gain);
    if (winners.isEmpty) return Center(child: Text(empty, style: Pb.t(40, weight: 600, color: Pb.muted)));
    return Wrap(spacing: 34, runSpacing: 12, children: [
      for (final r in winners.take(8))
        if (room.player(r.pid) case final p?)
          Row(mainAxisSize: MainAxisSize.min, children: [
            PbAvatar(size: 72, emoji: p.emoji, color: p.color, photoPath: p.photo),
            const SizedBox(width: 10),
            Text('+${Pb.pts(r.gain)}', style: Pb.t(40, weight: 700, color: Pb.green)),
          ]),
    ]);
  }
}

/// Podium de fin de partie (commun aux jeux)
class TvPodium extends StatelessWidget {
  const TvPodium({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ranking = live.ranking;
    GameRank? at(int i) => i < ranking.length ? ranking[i] : null;
    final rest = ranking.skip(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 50, 80, 40),
      child: Column(children: [
        Text('🏆 Podium', style: Pb.t(84, weight: 700)),
        const SizedBox(height: 10),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            _step(at(1), 2, 220, const Color(0xFFC0C8D8)),
            const SizedBox(width: 30),
            _step(at(0), 1, 300, Pb.yellow),
            const SizedBox(width: 30),
            _step(at(2), 3, 160, const Color(0xFFE0995E)),
          ]),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 26),
          Wrap(spacing: 40, runSpacing: 10, alignment: WrapAlignment.center, children: [
            for (final r in rest)
              if (room.player(r.pid) case final p?) Text('${r.rank}. ${p.name} · ${Pb.pts(r.score)}', style: Pb.t(34, color: Pb.muted)),
          ]),
        ],
        const SizedBox(height: 20),
        Countdown(
          endsIn: live.endsIn,
          duration: live.duration,
          builder: (_, _, s) => Text('Retour au salon dans $s s (ou quand ${room.host?.name ?? 'l’hôte'} le décide)',
              style: Pb.t(30, color: Pb.muted)),
        ),
      ]),
    );
  }

  Widget _step(GameRank? r, int place, double h, Color c) {
    final p = r == null ? null : room.player(r.pid);
    return SizedBox(
      width: 380,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 700 + (3 - place) * 400),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.translate(offset: Offset(0, 120 * (1 - v)), child: child)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (p != null) ...[
            if (place == 1) const Text('👑', style: TextStyle(fontSize: 60, height: 1)),
            PbAvatar(size: place == 1 ? 180 : 150, emoji: p.emoji, color: p.color, photoPath: p.photo),
            const SizedBox(height: 14),
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(46, weight: 700)),
            Text('${Pb.pts(r!.score)} pts', style: Pb.t(36, weight: 600, color: c)),
            const SizedBox(height: 16),
          ],
          Container(
            height: h,
            width: double.infinity,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c, c.withValues(alpha: .35)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Text('${r?.rank ?? place}', style: Pb.t(96, weight: 700, color: Pb.bg)),
          ),
        ]),
      ),
    );
  }
}

/// Une étiquette arrondie
class TvChip extends StatelessWidget {
  const TvChip({super.key, required this.text, this.color = Pb.text, this.bg = Pb.cardHi, this.size = 32});
  final String text;
  final Color color, bg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: size * .75, vertical: size * .25),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(40)),
        child: Text(text, style: Pb.t(size, weight: 600, color: color)),
      );
}

// =================================================================== téléphone

/// Grand message centré (emoji, titre, sous-titre)
class PhoneCenter extends StatelessWidget {
  const PhoneCenter({super.key, required this.emoji, required this.title, this.sub, this.color = Pb.text, this.extra});
  final String emoji, title;
  final String? sub;
  final Color color;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .3, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Text(emoji, style: const TextStyle(fontSize: 84)),
          ),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: Pb.t(30, weight: 700, color: color)),
          if (extra != null) ...[const SizedBox(height: 8), extra!],
          if (sub != null) ...[
            const SizedBox(height: 10),
            Text(sub!, textAlign: TextAlign.center, style: Pb.t(18, color: Pb.muted)),
          ],
        ]),
      ),
    );
  }
}

/// Résultat perso : points gagnés à cette manche
Widget phoneGain(Map<String, dynamic>? you, {String good = 'Bien joué !', String none = 'Pas de points cette fois'}) {
  final g = you.yi('gain') ?? 0;
  return PhoneCenter(
    emoji: g > 0 ? '🎉' : '🙃',
    title: g > 0 ? good : none,
    color: g > 0 ? Pb.green : Pb.text,
    extra: g > 0 ? Text('+${Pb.pts(g)}', style: Pb.t(50, weight: 700, color: Pb.green)) : null,
    sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
  );
}

/// Place finale
Widget phoneRank(Map<String, dynamic>? you) {
  final rank = you.yi('rank');
  final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '🎯' };
  return PhoneCenter(
    emoji: medal,
    title: rank == null ? 'Fin de la partie' : '${rank == 1 ? '1re' : '${rank}e'} place !',
    sub: '${Pb.pts(you.yi('score') ?? 0)} points · ${you.yi('players') ?? 0} joueurs',
    color: rank == 1 ? Pb.yellow : Pb.text,
  );
}

/// Barre de l'hôte : passer / arrêter, ou retour au salon depuis le podium
class PhoneHostBar extends StatelessWidget {
  const PhoneHostBar({super.key, required this.phase, required this.send, this.skipLabel = 'Suivant'});
  final String phase;
  final void Function(Map<String, dynamic>) send;
  final String skipLabel;

  void _g(Map<String, dynamic> m) => send({'t': 'game_msg', 'm': m});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: phase == 'podium'
            ? FilledButton(onPressed: () => _g({'t': 'game_skip'}), child: const Text('Retour au salon'))
            : Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _g({'t': 'game_skip'}), child: Text(skipLabel))),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Pb.bg2,
                          title: Text('Arrêter la partie ?', style: Pb.t(22, weight: 600)),
                          content: Text('On passe directement au podium.', style: Pb.t(17, color: Pb.muted)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuer')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arrêter')),
                          ],
                        ),
                      );
                      if (ok == true) _g({'t': 'game_end'});
                    },
                    child: const Text('Arrêter'),
                  ),
                ),
              ]),
      ),
    );
  }
}

/// Squelette d'un écran de jeu côté téléphone : contenu + barre de l'hôte
class PhoneGameFrame extends StatelessWidget {
  const PhoneGameFrame({super.key, required this.stepKey, required this.child, required this.isHost, required this.phase, required this.send});
  final String stepKey;
  final Widget child;
  final bool isHost;
  final String phase;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(stepKey), child: child),
        ),
      ),
      if (isHost) PhoneHostBar(phase: phase, send: send),
    ]);
  }
}

/// Transition douce entre les étapes d'un jeu, côté TV
class TvSwitcher extends StatelessWidget {
  const TvSwitcher({super.key, required this.stepKey, required this.child});
  final String stepKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
        child: KeyedSubtree(key: ValueKey(stepKey), child: child),
      );
}
