import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common_ui.dart' show rowAvatar, tvTwoCols, TvPodium;
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'quiz_state.dart';

/// Quiz sur la TV (toile 1920×1080).
class QuizTv extends StatelessWidget {
  const QuizTv({super.key, required this.room, required this.q});
  final RoomView room;
  final QuizState q;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (q.phase) {
      'intro' => _Intro(q: q),
      'question' || 'reveal' => _Question(room: room, q: q),
      'scores' => _Scores(room: room, q: q),
      // Podium commun (feu d'artifice et classement complet compris)
      'podium' => TvPodium(room: room, live: {
          'endsIn': q.endsIn,
          'duration': q.duration,
          'ranking': [for (final r in q.ranking) {'pid': r.pid, 'score': r.score, 'rank': r.rank, 'gain': r.gain}],
        }),
      _ => const SizedBox.shrink(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: .97, end: 1.0).animate(a), child: child),
      ),
      // La question et sa révélation gardent le même écran (pas de clignotement)
      child: KeyedSubtree(key: ValueKey(q.phase == 'reveal' ? 'question-${q.index}' : q.stepKey), child: body),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.q});
  final QuizState q;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🧠', style: TextStyle(fontSize: 180)),
        Text('Quiz culture G', style: Pb.t(110, weight: 700)),
        const SizedBox(height: 16),
        Text('${q.count} questions', style: Pb.t(54, weight: 600, color: Pb.yellow)),
        const SizedBox(height: 50),
        Text('Réponds sur ton téléphone.\nPlus tu es rapide, plus tu gagnes de points !',
            textAlign: TextAlign.center, style: Pb.t(44, color: Pb.muted, height: 1.3)),
        const SizedBox(height: 60),
        TimeCircle(endsIn: q.endsIn, duration: q.duration, size: 130),
      ]),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.room, required this.q});
  final RoomView room;
  final QuizState q;

  bool get reveal => q.phase == 'reveal';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 50, 80, 50),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ---- en-tête ----
        Row(children: [
          Text('Question ${q.index + 1}', style: Pb.t(44, weight: 700)),
          Text(' / ${q.count}', style: Pb.t(44, weight: 500, color: Pb.muted)),
          const SizedBox(width: 30),
          _Chip(text: '${Pb.categoryEmoji(q.category)}  ${q.category ?? ''}'),
          const SizedBox(width: 14),
          _Chip(text: '★' * q.difficulty + '☆' * (3 - q.difficulty), color: Pb.yellow),
          const Spacer(),
          if (!reveal) TimeCircle(endsIn: q.endsIn, duration: q.duration, size: 110),
        ]),
        const SizedBox(height: 30),
        // ---- question ----
        Expanded(
          flex: 3,
          child: Center(
            child: Text(
              q.question ?? '',
              textAlign: TextAlign.center,
              style: Pb.t(q.question != null && q.question!.length > 70 ? 66 : 76, weight: 700, height: 1.15),
            ),
          ),
        ),
        if (!reveal) ...[
          TimeBar(endsIn: q.endsIn, duration: q.duration, height: 16),
          const SizedBox(height: 30),
        ] else
          const SizedBox(height: 46),
        // ---- réponses 2×2 ----
        Expanded(
          flex: 4,
          child: Column(children: [
            for (final row in [
              [0, 1],
              [2, 3],
            ]) ...[
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final i in row) ...[
                    Expanded(child: _answer(i)),
                    if (i == row.first) const SizedBox(width: 28),
                  ],
                ]),
              ),
              if (row.first == 0) const SizedBox(height: 28),
            ],
          ]),
        ),
        const SizedBox(height: 30),
        // ---- qui a répondu ----
        SizedBox(height: 96, child: reveal ? _gains() : _whoAnswered()),
      ]),
    );
  }

  Widget _answer(int i) {
    if (i >= q.answers.length) return const SizedBox.shrink();
    final good = reveal && q.correct == i;
    final dim = reveal && !good;
    final who = [for (final e in q.picks.entries) if (e.value == i) room.player(e.key)].whereType<PlayerView>().toList();
    final c = Pb.answerColors[i];
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: dim ? .3 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        scale: good ? 1.03 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(32),
            border: good ? Border.all(color: Colors.white, width: 8) : null,
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: good ? .8 : .35), blurRadius: good ? 50 : 20),
            ],
          ),
          child: Row(children: [
            Icon(Pb.answerIcons[i], size: 64, color: Colors.white.withValues(alpha: .9)),
            const SizedBox(width: 26),
            Expanded(
              child: Text(
                q.answers[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Pb.t(q.answers[i].length > 22 ? 46 : 54, weight: 700, color: Colors.white, height: 1.1),
              ),
            ),
            if (reveal) ...[
              for (final p in who.take(5))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: PbAvatar(size: 64, emoji: p.emoji, color: p.color, photoPath: p.photo),
                ),
              if (who.length > 5) Text(' +${who.length - 5}', style: Pb.t(36, weight: 700, color: Colors.white)),
              if (good) const Padding(padding: EdgeInsets.only(left: 14), child: Text('✅', style: TextStyle(fontSize: 56))),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _whoAnswered() {
    final players = room.players.where((p) => p.connected).toList();
    return Row(children: [
      Text('${q.answered.length}/${players.length} ont répondu', style: Pb.t(36, weight: 600, color: Pb.muted)),
      const SizedBox(width: 30),
      for (final p in players)
        Padding(
          padding: EdgeInsets.only(right: players.length > 9 ? 8 : 14),
          child: Stack(clipBehavior: Clip.none, children: [
            PbAvatar(size: players.length > 9 ? rowAvatar(players.length) : 80, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !q.answered.contains(p.pid)),
            if (q.answered.contains(p.pid))
              const Positioned(right: -6, bottom: -6, child: Text('✔️', style: TextStyle(fontSize: 34))),
          ]),
        ),
    ]);
  }

  Widget _gains() {
    final winners = q.ranking.where((r) => r.gain > 0).toList()..sort((a, b) => b.gain - a.gain);
    if (winners.isEmpty) {
      return Center(child: Text('Personne n’a trouvé ! 😅', style: Pb.t(44, weight: 600, color: Pb.muted)));
    }
    return Row(children: [
      for (final r in winners.take(6))
        if (room.player(r.pid) case final p?)
          Padding(
            padding: const EdgeInsets.only(right: 34),
            child: Row(children: [
              PbAvatar(size: 80, emoji: p.emoji, color: p.color, photoPath: p.photo),
              const SizedBox(width: 12),
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('+${Pb.pts(r.gain)}', style: Pb.t(40, weight: 700, color: Pb.green, height: 1)),
                if (r.streak >= 2) Text('🔥 ${r.streak} d’affilée', style: Pb.t(26, color: Pb.yellow)),
              ]),
            ]),
          ),
    ]);
  }
}

class _Scores extends StatelessWidget {
  const _Scores({required this.room, required this.q});
  final RoomView room;
  final QuizState q;

  @override
  Widget build(BuildContext context) {
    final list = q.ranking;
    // Jusqu'à 8 joueurs : grandes lignes avec barres ; au-delà, deux colonnes plus petites
    final two = list.length > 8;
    final k = two ? .72 : 1.0;
    final top = list.isEmpty ? 1 : (list.first.score == 0 ? 1 : list.first.score);
    return Padding(
      padding: EdgeInsets.fromLTRB(two ? 80 : 160, 70, two ? 80 : 160, 60),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Classement', style: Pb.t(76, weight: 700)),
          const Spacer(),
          Text('après ${q.index + 1} question${q.index > 0 ? 's' : ''} sur ${q.count}', style: Pb.t(38, color: Pb.muted)),
        ]),
        SizedBox(height: two ? 30 : 40),
        tvTwoCols(gap: 70, [
        for (var i = 0; i < list.length; i++)
          if (room.player(list[i].pid) case final p?)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + i * 120),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: 18 * k),
                child: Row(children: [
                  SizedBox(width: 80 * k, child: Text('${list[i].rank}', style: Pb.t(54 * k, weight: 700, color: Pb.muted))),
                  PbAvatar(size: 84 * k, emoji: p.emoji, color: p.color, photoPath: p.photo),
                  SizedBox(width: 22 * k),
                  SizedBox(width: two ? 220 : 380, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(46 * k, weight: 600))),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: (list[i].score - list[i].gain) / top, end: list[i].score / top),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (_, f, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: f.clamp(.02, 1.0),
                          child: Container(
                            height: 44 * k,
                            decoration: BoxDecoration(
                              color: Pb.playerColor(p.color),
                              borderRadius: BorderRadius.circular(22 * k),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 24 * k),
                  SizedBox(
                    width: 220 * k,
                    child: Text(Pb.pts(list[i].score), textAlign: TextAlign.right, style: Pb.t(48 * k, weight: 700)),
                  ),
                  SizedBox(
                    width: 70 * k,
                    child: Text(
                      q.index == 0 ? '' : (list[i].rank < list[i].prevRank ? '▲' : (list[i].rank > list[i].prevRank ? '▼' : '')),
                      textAlign: TextAlign.right,
                      style: Pb.t(40 * k, color: list[i].rank < list[i].prevRank ? Pb.green : Pb.red),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.color = Pb.text});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(color: Pb.cardHi, borderRadius: BorderRadius.circular(40)),
        child: Text(text, style: Pb.t(32, weight: 600, color: color)),
      );
}
