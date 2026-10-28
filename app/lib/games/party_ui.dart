import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

/// Équipes, soirée enchaînée et statistiques : les écrans TV et téléphone.

// =================================================================== équipes

/// Score de chaque équipe (TV) : pastilles colorées
class TvTeamsBar extends StatelessWidget {
  const TvTeamsBar({super.key, required this.teams, this.scores, this.size = 32});
  final TeamsView teams;
  final List<int>? scores; // par défaut : score de la soirée
  final double size;

  @override
  Widget build(BuildContext context) {
    final sc = scores ?? teams.scores;
    final best = sc.isEmpty ? 0 : sc.reduce((a, b) => a > b ? a : b);
    return Wrap(spacing: 18, runSpacing: 10, alignment: WrapAlignment.center, children: [
      for (var i = 0; i < teams.count; i++)
        Container(
          padding: EdgeInsets.symmetric(horizontal: size * .7, vertical: size * .25),
          decoration: BoxDecoration(
            color: TeamsView.color(i).withValues(alpha: .25),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: TeamsView.color(i), width: size * .1),
          ),
          child: Text('${best > 0 && i < sc.length && sc[i] == best ? '👑 ' : ''}${teams.names[i]} · ${Pb.pts(i < sc.length ? sc[i] : 0)}',
              style: Pb.t(size, weight: 700)),
        ),
    ]);
  }
}

/// Totaux d'équipe d'une partie, calculés d'après le classement de la partie
List<int> teamTotals(RoomView room, List<GameRank> ranking) {
  final t = room.teams;
  if (t == null) return const [];
  final pts = List.filled(t.count, 0);
  for (final r in ranking) {
    final team = room.player(r.pid)?.team;
    if (team != null && team < t.count) pts[team] += r.score;
  }
  return pts;
}

/// Section « Équipes » du salon sur le téléphone : choisir son équipe ; l'hôte règle tout
class PhoneTeams extends StatelessWidget {
  const PhoneTeams({super.key, required this.room, required this.myPid, required this.isHost, required this.send});
  final RoomView room;
  final String? myPid;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final t = room.teams;
    final me = room.player(myPid ?? '');
    if (t == null && !isHost) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 12),
      decoration: BoxDecoration(color: Pb.card.withValues(alpha: .7), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('👨‍👩‍👧 Équipes', style: Pb.t(17, weight: 700)),
          const Spacer(),
          if (isHost) Switch(value: t != null, activeThumbColor: Pb.pink, onChanged: (v) => send({'t': 'teams_set', 'on': v})),
        ]),
        if (t != null) ...[
          if (isHost)
            Row(children: [
              Text('Nombre', style: Pb.t(14, color: Pb.muted)),
              for (final n in [2, 3, 4])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$n', style: Pb.t(14, weight: 600)),
                    selected: t.count == n,
                    showCheckmark: false,
                    selectedColor: Pb.pink,
                    backgroundColor: Pb.bg2,
                    side: BorderSide.none,
                    onSelected: (_) => send({'t': 'teams_set', 'on': true, 'count': n}),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => send({'t': 'teams_shuffle'}),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Mélanger'),
              ),
            ]),
          const SizedBox(height: 6),
          Text(isHost ? 'Touche une équipe pour la rejoindre, ✏️ pour la renommer' : 'Touche une équipe pour la rejoindre',
              style: Pb.t(13, color: Pb.muted)),
          const SizedBox(height: 8),
          for (var i = 0; i < t.count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: TeamsView.color(i).withValues(alpha: me?.team == i ? .45 : .18),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    send({'t': 'team_pick', 'i': i});
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(children: [
                      Container(width: 14, height: 14, decoration: BoxDecoration(color: TeamsView.color(i), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${t.names[i]}${me?.team == i ? '  (toi)' : ''}', style: Pb.t(16, weight: 700)),
                          Wrap(spacing: 4, runSpacing: 4, children: [
                            for (final p in room.players.where((p) => p.team == i))
                              PbAvatar(size: 26, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !p.connected),
                          ]),
                        ]),
                      ),
                      Text(Pb.pts(t.scores[i]), style: Pb.t(15, weight: 700, color: Pb.yellow)),
                      if (isHost)
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18, color: Pb.muted),
                          onPressed: () => _rename(context, i, t.names[i]),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ]),
    );
  }

  Future<void> _rename(BuildContext context, int i, String current) async {
    final c = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pb.bg2,
        title: Text('Nom de l’équipe', style: Pb.t(20, weight: 700)),
        content: TextField(controller: c, autofocus: true, maxLength: 16, decoration: const InputDecoration(counterText: '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    c.dispose();
    if (name != null && name.isNotEmpty) send({'t': 'team_name', 'i': i, 'name': name});
  }
}

// =================================================================== soirée enchaînée

/// L'hôte choisit les jeux de la soirée (dans l'ordre où il les touche)
class SoireePicker extends StatefulWidget {
  const SoireePicker({super.key, required this.room, required this.send});
  final RoomView room;
  final void Function(Map<String, dynamic>) send;

  @override
  State<SoireePicker> createState() => _SoireePickerState();
}

class _SoireePickerState extends State<SoireePicker> {
  final _list = <String>[];

  @override
  Widget build(BuildContext context) {
    final games = widget.room.games.where((g) => g.ready).toList();
    final n = widget.room.players.where((p) => p.connected).length;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(children: [
          const SizedBox(height: 16),
          Text('🎯 Soirée enchaînée', style: Pb.t(22, weight: 700)),
          Text('Touche les jeux dans l’ordre (2 à 6). Classement général entre chaque jeu, grand podium à la fin.',
              textAlign: TextAlign.center, style: Pb.t(14, color: Pb.muted)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              for (final g in games)
                Builder(builder: (_) {
                  final pos = _list.indexOf(g.id);
                  final tooFew = n < g.min;
                  return ListTile(
                    enabled: !tooFew,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    leading: Text(g.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(g.title, style: Pb.t(17, weight: 600)),
                    subtitle: tooFew ? Text('${g.min} joueurs minimum', style: Pb.t(13, color: Pb.yellow)) : null,
                    trailing: pos < 0
                        ? const Icon(Icons.add_circle_outline_rounded, color: Pb.muted)
                        : CircleAvatar(radius: 15, backgroundColor: Pb.pink, child: Text('${pos + 1}', style: Pb.t(15, weight: 700))),
                    onTap: () => setState(() {
                      if (pos >= 0) {
                        _list.remove(g.id);
                      } else if (_list.length < 6) {
                        _list.add(g.id);
                      }
                    }),
                  );
                }),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: FilledButton(
              onPressed: _list.length < 2
                  ? null
                  : () {
                      widget.send({'t': 'soiree_start', 'games': _list});
                      Navigator.pop(context);
                    },
              child: Text(_list.length < 2 ? 'Choisis au moins 2 jeux' : 'Lancer la soirée (${_list.length} jeux)'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Classement de la soirée en liste (TV)
Widget _soireeList(RoomView room, SoireeView so, {int max = 10, double size = 38}) => Column(mainAxisSize: MainAxisSize.min, children: [
      for (final r in so.ranking.take(max))
        if (room.player(r.pid) case final p?)
          Container(
            width: 900,
            margin: EdgeInsets.only(bottom: size * .22),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: size * .14),
            decoration: BoxDecoration(
              color: r.rank == 1 ? Pb.cardHi : Pb.card.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(24),
              border: r.rank == 1 ? Border.all(color: Pb.yellow, width: 3) : null,
            ),
            child: Row(children: [
              SizedBox(width: size * 1.6, child: Text(r.rank == 1 ? '👑' : '${r.rank}.', style: Pb.t(size, weight: 700, color: Pb.muted))),
              PbAvatar(size: size * 1.5, emoji: p.emoji, color: p.color, photoPath: p.photo),
              const SizedBox(width: 16),
              if (room.teams != null && p.team != null)
                Container(width: 12, height: size, margin: const EdgeInsets.only(right: 12), color: TeamsView.color(p.team!)),
              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(size, weight: 600))),
              Text(Pb.pts(r.score), style: Pb.t(size, weight: 700, color: Pb.yellow)),
            ]),
          ),
    ]);

/// Entracte et podium final de la soirée, sur la TV
class TvSoiree extends StatelessWidget {
  const TvSoiree({super.key, required this.room});
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    final so = room.soiree!;
    final teams = room.teams;
    if (so.step == 'final') {
      // Le podium commun (feu d'artifice compris), avec le classement de toute la soirée
      final live = <String, dynamic>{
        'endsIn': so.endsIn,
        'duration': so.duration,
        'ranking': [for (final r in so.ranking) {'pid': r.pid, 'score': r.score, 'rank': r.rank, 'gain': 0}],
      };
      return Stack(children: [
        TvPodium(room: room, live: live, title: '🏆 Podium de la soirée'),
        if (teams != null && so.teams != null)
          Positioned(top: 150, left: 0, right: 0, child: Center(child: TvTeamsBar(teams: teams, scores: so.teams, size: 34))),
      ]);
    }
    final next = so.index + 1 < so.games.length ? room.gameById(so.games[so.index + 1]) : null;
    final done = room.gameById(so.last ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 50, 80, 40),
      child: Column(children: [
        Text('🎯 Soirée : ${so.index + 1} / ${so.games.length}', style: Pb.t(44, weight: 700, color: Pb.muted)),
        Text('Classement général', style: Pb.t(80, weight: 700)),
        if (done != null) Text('après ${done.emoji} ${done.title}', style: Pb.t(36, color: Pb.muted)),
        const SizedBox(height: 20),
        if (teams != null && so.teams != null) ...[TvTeamsBar(teams: teams, scores: so.teams, size: 36), const SizedBox(height: 20)],
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Center(child: _soireeList(room, so, max: teams != null ? 7 : 9, size: teams != null ? 32 : 36)),
          ),
        ),
        if (next != null)
          Countdown(
            endsIn: so.endsIn,
            duration: so.duration,
            builder: (_, _, s) => Text('Prochain jeu : ${next.emoji} ${next.title} dans $s s', style: Pb.t(46, weight: 700, color: Pb.yellow)),
          ),
      ]),
    );
  }
}

/// Entracte et fin de soirée, sur le téléphone
class PhoneSoiree extends StatelessWidget {
  const PhoneSoiree({super.key, required this.room, required this.myPid, required this.isHost, required this.send});
  final RoomView room;
  final String? myPid;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final so = room.soiree!;
    final me = so.ranking.where((r) => r.pid == myPid).firstOrNull;
    final fin = so.step == 'final';
    final next = so.index + 1 < so.games.length ? room.gameById(so.games[so.index + 1]) : null;
    return Column(children: [
      Expanded(
        child: PhoneCenter(
          emoji: fin ? (me?.rank == 1 ? '🏆' : '🎉') : '📊',
          title: me == null ? 'Soirée' : '${me.rank == 1 ? '1re' : '${me.rank}e'} place${fin ? ' de la soirée !' : ''}',
          color: me?.rank == 1 ? Pb.yellow : Pb.text,
          extra: Text('${Pb.pts(me?.score ?? 0)} points', style: Pb.t(30, weight: 700, color: Pb.yellow)),
          sub: fin ? 'Bravo à tous ! 🎆' : (next == null ? '' : 'Prochain jeu : ${next.emoji} ${next.title}'),
        ),
      ),
      if (isHost)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              if (!fin) ...[
                Expanded(child: OutlinedButton(onPressed: () => send({'t': 'soiree_stop'}), child: const Text('Arrêter'))),
                const SizedBox(width: 10),
              ],
              Expanded(child: FilledButton(onPressed: () => send({'t': 'soiree_next'}), child: Text(fin ? 'Retour au salon' : 'Jeu suivant'))),
            ]),
          ),
        ),
    ]);
  }
}

// =================================================================== statistiques

/// Statistiques d'un salon permanent (reçues du serveur : perm_stats)
class PermStatsView extends StatelessWidget {
  const PermStatsView({super.key, required this.stats, required this.games, this.scale = 1, this.wide = false});
  final Map<String, dynamic> stats;
  final List<GameInfo> games;
  final double scale;
  final bool wide; // TV : classement et champions côte à côte

  @override
  Widget build(BuildContext context) {
    final members = [for (final m in (stats['members'] as List? ?? const [])) m as Map<String, dynamic>];
    final champs = [for (final c in (stats['champions'] as List? ?? const [])) c as Map<String, dynamic>];
    String title(String id) => id == 'soiree' ? '🎯 Soirées enchaînées' : (() {
          final g = games.where((x) => x.id == id).firstOrNull;
          return g == null ? id : '${g.emoji} ${g.title}';
        })();
    final s = scale;
    final board = <Widget>[
      Text('🏆 Classement de tous les temps', style: Pb.t(20 * s, weight: 700)),
      SizedBox(height: 8 * s),
      if (members.isEmpty) Text('Personne n’a encore joué ici.', style: Pb.t(15 * s, color: Pb.muted)),
      for (final (i, m) in members.take(10).indexed)
        Padding(
          padding: EdgeInsets.only(bottom: 6 * s),
          child: Row(children: [
            SizedBox(width: 34 * s, child: Text(i == 0 ? '👑' : '${i + 1}.', style: Pb.t(16 * s, weight: 700, color: Pb.muted))),
            PbAvatar(size: 32 * s, emoji: m['emoji'] as String? ?? '🙂', color: (m['color'] as num?)?.toInt() ?? 0),
            SizedBox(width: 10 * s),
            Expanded(child: Text(m['name'] as String? ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(16 * s, weight: 600))),
            Text('${m['games']} partie${(m['games'] as num? ?? 0) > 1 ? 's' : ''}  ', style: Pb.t(13 * s, color: Pb.muted)),
            Text(Pb.pts(m['score'] as num? ?? 0), style: Pb.t(16 * s, weight: 700, color: Pb.yellow)),
          ]),
        ),
    ];
    final champions = <Widget>[
        Text('🥇 Champions par jeu', style: Pb.t(20 * s, weight: 700)),
        if (champs.isEmpty) Text('Pas encore de champion.', style: Pb.t(15 * s, color: Pb.muted)),
        SizedBox(height: 8 * s),
        for (final c in champs)
          Padding(
            padding: EdgeInsets.only(bottom: 6 * s),
            child: Row(children: [
              Expanded(child: Text(title(c['game'] as String), maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(15 * s, weight: 600))),
              PbAvatar(size: 26 * s, emoji: c['emoji'] as String? ?? '🙂', color: (c['color'] as num?)?.toInt() ?? 0),
              SizedBox(width: 6 * s),
              Text('${c['name']}', style: Pb.t(15 * s, weight: 700)),
              Text('  ${c['wins']} victoire${(c['wins'] as num) > 1 ? 's' : ''}', style: Pb.t(13 * s, color: Pb.muted)),
            ]),
          ),
    ];
    Widget col(List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: c);
    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: col(board)),
        SizedBox(width: 30 * s),
        Expanded(child: col(champions)),
      ]);
    }
    return col([...board, SizedBox(height: 14 * s), ...champions]);
  }
}
