import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/countdown.dart';
import '../widgets/fireworks.dart';
import 'quiz_state.dart';

/// Quiz sur le téléphone : 4 gros boutons, puis le résultat.
class QuizPlay extends StatelessWidget {
  const QuizPlay({
    super.key,
    required this.room,
    required this.q,
    required this.you,
    required this.isHost,
    required this.send,
  });

  final RoomView room;
  final QuizState q;
  final QuizYou? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  void _game(Map<String, dynamic> m) => send({'t': 'game_msg', 'm': m});

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (q.phase) {
      'intro' => _center('🧠', 'Prépare-toi !', '${q.count} questions. Regarde la TV, réponds ici.'),
      'question' => _question(),
      'reveal' => _reveal(),
      'scores' => _rankView(),
      'podium' => _rankView(final_: true),
      _ => const SizedBox.shrink(),
    };
    return Column(children: [
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey('${q.stepKey}-${you?.choice}'), child: body),
        ),
      ),
      if (isHost) _hostBar(context),
    ]);
  }

  // ---- question : 4 boutons ----
  Widget _question() {
    final chosen = you?.choice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('Question ${q.index + 1}/${q.count}', style: Pb.t(16, weight: 600, color: Pb.muted)),
          const Spacer(),
          Text('${Pb.categoryEmoji(q.category)} ${q.category ?? ''}', style: Pb.t(15, color: Pb.muted)),
        ]),
        const SizedBox(height: 8),
        TimeBar(endsIn: q.endsIn, duration: q.duration, height: 8),
        const SizedBox(height: 12),
        Text(q.question ?? '', textAlign: TextAlign.center, style: Pb.t(19, weight: 600, height: 1.2)),
        const SizedBox(height: 14),
        Expanded(
          child: Column(children: [
            for (var i = 0; i < q.answers.length; i++) ...[
              Expanded(child: _button(i, chosen)),
              if (i < q.answers.length - 1) const SizedBox(height: 10),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 26,
          child: chosen == null
              ? null
              : Text('Réponse envoyée ! Regarde la TV 📺', textAlign: TextAlign.center, style: Pb.t(17, weight: 600, color: Pb.green)),
        ),
      ]),
    );
  }

  Widget _button(int i, int? chosen) {
    final c = Pb.answerColors[i];
    final locked = chosen != null;
    final mine = chosen == i;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: locked && !mine ? .25 : 1,
      child: Material(
        color: c,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: locked
              ? null
              : () {
                  HapticFeedback.heavyImpact();
                  _game({'t': 'quiz_answer', 'q': q.index, 'choice': i});
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: mine ? Border.all(color: Colors.white, width: 4) : null,
            ),
            child: Row(children: [
              Icon(Pb.answerIcons[i], color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Text(q.answers[i],
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(21, weight: 700, color: Colors.white, height: 1.1)),
              ),
              if (mine) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 30),
            ]),
          ),
        ),
      ),
    );
  }

  // ---- révélation : gagné / perdu ----
  Widget _reveal() {
    final y = you;
    final chosen = y?.choice;
    final good = chosen != null && chosen == q.correct;
    final answer = q.correct != null && q.correct! < q.answers.length ? q.answers[q.correct!] : '';
    if (chosen == null) {
      return _center('⏱️', 'Trop tard…', 'La réponse était : $answer', color: Pb.muted);
    }
    if (!good) {
      return _center('❌', 'Raté !', 'La réponse était : $answer', color: Pb.red);
    }
    return _center('✅', 'Bonne réponse !', null,
        color: Pb.green,
        extra: Column(children: [
          Text('+${Pb.pts(y?.gain ?? 0)}', style: Pb.t(54, weight: 700, color: Pb.green)),
          if ((y?.streak ?? 0) >= 2) Text('🔥 ${y!.streak} bonnes réponses d’affilée', style: Pb.t(17, color: Pb.yellow)),
        ]));
  }

  // ---- classement perso ----
  Widget _rankView({bool final_ = false}) {
    final y = you;
    final rank = y?.rank;
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '🎯' };
    final view = _center(
      final_ ? medal : '📊',
      rank == null ? 'Classement' : '${rank == 1 ? '1re' : '${rank}e'} place${final_ ? ' !' : ''}',
      '${Pb.pts(y?.score ?? 0)} points · ${y?.players ?? 0} joueurs',
      color: rank == 1 ? Pb.yellow : Pb.text,
    );
    if (!final_ || rank != 1) return view;
    return Stack(children: [view, const Positioned.fill(child: Fireworks(seconds: 5))]);
  }

  Widget _center(String emoji, String title, String? sub, {Color color = Pb.text, Widget? extra}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .3, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Text(emoji, style: const TextStyle(fontSize: 90)),
          ),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: Pb.t(32, weight: 700, color: color)),
          if (extra != null) ...[const SizedBox(height: 6), extra],
          if (sub != null) ...[
            const SizedBox(height: 10),
            Text(sub, textAlign: TextAlign.center, style: Pb.t(18, color: Pb.muted)),
          ],
        ]),
      ),
    );
  }

  // ---- commandes de l'hôte ----
  Widget _hostBar(BuildContext context) {
    final podium = q.phase == 'podium';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: podium
            ? FilledButton(onPressed: () => _game({'t': 'game_skip'}), child: const Text('Retour au salon'))
            : Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _game({'t': 'game_skip'}),
                    child: Text(q.phase == 'question' ? 'Révéler' : 'Suivant'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmEnd(context),
                    child: const Text('Arrêter'),
                  ),
                ),
              ]),
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context) async {
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
    if (ok == true) _game({'t': 'game_end'});
  }
}
