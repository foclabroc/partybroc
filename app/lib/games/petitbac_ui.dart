import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';

/// Petit bac sur la TV
class BacTv extends StatelessWidget {
  const BacTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '✍️',
          title: 'Petit bac',
          sub: '${live.i('count')} lettres · ${live.pids('categories').join(', ')}',
          rules: const [
            'Un mot par catégorie, qui commence par la lettre. Le premier qui a tout rempli crie « Stop ! » : 10 secondes pour les autres.',
            'Ensuite on vérifie : chacun peut refuser les réponses des autres. Réponse unique 100, en double 50, seul à avoir trouvé 150.',
          ],
          live: live),
      'write' => _write(),
      'check' || 'reveal' => _table(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '$ph-${live.i('index')}', child: body);
  }

  Widget _letter(double size) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Pb.yellow, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Pb.yellow.withValues(alpha: .45), blurRadius: size * .2)]),
        child: Text(live.s('letter') ?? '?', style: Pb.t(size * .62, weight: 700, color: Pb.bg, height: 1)),
      );

  Widget _write() {
    final stop = room.player(live.s('stopBy') ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(children: [
        TvHeader(label: 'Lettre', index: live.i('index'), count: live.i('count'), live: live),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _letter(330),
            const SizedBox(width: 90),
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final c in live.pids('categories'))
                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('•  $c', style: Pb.t(56, weight: 600))),
            ]),
          ]),
        ),
        if (stop != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TvChip(text: '✋ ${stop.name} a crié STOP ! Vite, plus que quelques secondes !', bg: Pb.red, size: 44),
          ),
        TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
        const SizedBox(height: 24),
        SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('done').toSet(), label: 'ont fini')),
      ]),
    );
  }

  // Tableau joueurs × catégories : pendant la vérification (refus), puis les points
  Widget _table() {
    final reveal = live.phase == 'reveal';
    final cats = live.pids('categories');
    final rows = <String, List<_Cell>>{};
    if (reveal) {
      final table = live.maps('table');
      for (var c = 0; c < table.length; c++) {
        for (final r in (table[c]['rows'] as List).cast<Map<String, dynamic>>()) {
          rows.putIfAbsent(r['pid'] as String, () => List.generate(cats.length, (_) => const _Cell('', false)))[c] =
              _Cell(r['text'] as String? ?? '', r['ok'] == true, pts: (r['pts'] as num?)?.toInt() ?? 0, refused: r['refused'] == true);
        }
      }
    } else {
      final sheets = (live['sheets'] as Map?) ?? const {};
      final vetoes = (live['vetoes'] as Map?) ?? const {};
      for (final e in sheets.entries) {
        final list = (e.value as List).cast<Map<String, dynamic>>();
        rows[e.key as String] = [
          for (var c = 0; c < list.length; c++)
            _Cell(list[c]['t'] as String? ?? '', list[c]['ok'] == true, vetoes: (vetoes['${e.key}:$c'] as num?)?.toInt() ?? 0),
        ];
      }
    }
    final gains = {for (final r in live.ranking) r.pid: r.gain};
    final n = rows.length;
    final fs = n > 10 ? 24.0 : (n > 6 ? 28.0 : 34.0);
    final rowH = n > 10 ? 44.0 : (n > 6 ? 58.0 : 76.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 36, 60, 30),
      child: Column(children: [
        Row(children: [
          _letter(110),
          const SizedBox(width: 30),
          Text(reveal ? 'Les points' : 'On vérifie ! Refuse sur ton téléphone les mots qui ne vont pas', style: Pb.t(reveal ? 56 : 40, weight: 700)),
          const Spacer(),
          if (!reveal) TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 96),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          SizedBox(width: 250, child: Text('', style: Pb.t(fs))),
          for (final c in cats) Expanded(child: Text(c, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(fs, weight: 700, color: Pb.cyan))),
          if (reveal) SizedBox(width: 120, child: Text('Total', textAlign: TextAlign.right, style: Pb.t(fs, weight: 700, color: Pb.cyan))),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(children: [
              for (final e in rows.entries)
                if (room.player(e.key) case final p?)
                  Container(
                    height: rowH,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(color: Pb.card.withValues(alpha: .6), borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      SizedBox(
                        width: 250,
                        child: Row(children: [
                          const SizedBox(width: 8),
                          PbAvatar(size: rowH - 10, emoji: p.emoji, color: p.color, photoPath: p.photo),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(fs, weight: 600))),
                        ]),
                      ),
                      for (final cell in e.value) Expanded(child: _cellView(cell, fs, reveal)),
                      if (reveal)
                        SizedBox(
                          width: 120,
                          child: Text('+${gains[p.pid] ?? 0}', textAlign: TextAlign.right, style: Pb.t(fs + 4, weight: 700, color: Pb.green)),
                        ),
                      const SizedBox(width: 12),
                    ]),
                  ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _cellView(_Cell c, double fs, bool reveal) {
    if (c.text.isEmpty) return Text('—', textAlign: TextAlign.center, style: Pb.t(fs, color: Pb.muted.withValues(alpha: .5)));
    final bad = !c.ok || c.refused;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Flexible(
        child: Text(
          c.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Pb.t(fs, weight: 600, color: bad ? Pb.muted : Pb.text).copyWith(decoration: bad && reveal ? TextDecoration.lineThrough : null),
        ),
      ),
      if (!reveal && c.vetoes > 0) Text(' ❌${c.vetoes}', style: Pb.t(fs * .8, weight: 700, color: Pb.red)),
      if (reveal && c.pts > 0) Text(' ${c.pts}', style: Pb.t(fs * .8, weight: 700, color: Pb.yellow)),
    ]);
  }
}

class _Cell {
  const _Cell(this.text, this.ok, {this.pts = 0, this.refused = false, this.vetoes = 0});
  final String text;
  final bool ok, refused;
  final int pts, vetoes;
}

/// Petit bac sur le téléphone
class BacPlay extends StatelessWidget {
  const BacPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
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
      'intro' => PhoneCenter(emoji: '✍️', title: 'Petit bac', sub: 'Catégories : ${live.pids('categories').join(', ')}'),
      'write' => _BacWrite(key: ValueKey('w${live.i('index')}'), live: live, you: you, send: send),
      'check' => _check(),
      'reveal' => phoneGain(you, good: 'Bien joué !', none: 'Pas de points cette lettre'),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}', isHost: isHost, phase: ph, send: send, child: body);
  }

  // Vérification : les mots des autres, un appui pour refuser
  Widget _check() {
    final cats = live.pids('categories');
    final sheets = (live['sheets'] as Map?) ?? const {};
    final mine = {for (final k in (you?['myVetoes'] as List?) ?? const []) k as String};
    final ok = you.yb('ok');
    return ListView(padding: const EdgeInsets.fromLTRB(14, 44, 14, 16), children: [
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 10),
      Text('Touche un mot pour le refuser ❌', textAlign: TextAlign.center, style: Pb.t(18, weight: 700)),
      Text('Refusé si la majorité des autres le refuse.', textAlign: TextAlign.center, style: Pb.t(14, color: Pb.muted)),
      const SizedBox(height: 10),
      for (var c = 0; c < cats.length; c++) ...[
        Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(cats[c], style: Pb.t(16, weight: 700, color: Pb.cyan))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in sheets.entries)
            if (e.key != myPid)
              if ((e.value as List)[c] case final Map cell when (cell['t'] as String? ?? '').isNotEmpty)
                Builder(builder: (_) {
                  final key = '${e.key}:$c';
                  final refused = mine.contains(key);
                  final valid = cell['ok'] == true;
                  return FilterChip(
                    label: Text('${cell['t']}  ·  ${room.player(e.key as String)?.name ?? '?'}', style: Pb.t(14, weight: 600, color: valid ? Pb.text : Pb.muted)),
                    selected: refused,
                    showCheckmark: false,
                    avatar: Text(refused ? '❌' : (valid ? '✅' : '⚠️')),
                    selectedColor: Pb.red.withValues(alpha: .45),
                    backgroundColor: Pb.card,
                    side: BorderSide.none,
                    onSelected: valid ? (on) => send({'t': 'game_msg', 'm': {'t': 'bac_veto', 'r': live.i('index'), 'pid': e.key, 'c': c, 'on': on}}) : null,
                  );
                }),
        ]),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: ok ? null : () => send({'t': 'game_msg', 'm': {'t': 'bac_ok', 'r': live.i('index')}}),
        child: Text(ok ? 'C’est noté, on attend les autres…' : 'C’est bon pour moi ✓'),
      ),
    ]);
  }
}

/// Écriture : un champ par catégorie, sauvegarde automatique, bouton « Stop ! »
class _BacWrite extends StatefulWidget {
  const _BacWrite({super.key, required this.live, required this.you, required this.send});
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final void Function(Map<String, dynamic>) send;

  @override
  State<_BacWrite> createState() => _BacWriteState();
}

class _BacWriteState extends State<_BacWrite> {
  late final List<String> _cats = widget.live.pids('categories');
  late final _c = [
    for (var i = 0; i < _cats.length; i++)
      TextEditingController(text: (((widget.you?['sheet'] as List?) ?? const [])).elementAtOrNull(i) as String? ?? ''),
  ];
  Timer? _save;

  @override
  void dispose() {
    _save?.cancel();
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  String get _letter => (widget.live.s('letter') ?? '?').toUpperCase();

  bool _starts(String t) {
    final s = t.trim();
    if (s.isEmpty) return false;
    const accents = {'À': 'A', 'Â': 'A', 'Ä': 'A', 'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E', 'Î': 'I', 'Ï': 'I', 'Ô': 'O', 'Ö': 'O', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', 'Ç': 'C'};
    final f = s[0].toUpperCase();
    return (accents[f] ?? f) == _letter && s.length >= 2;
  }

  void _push({bool done = false}) {
    widget.send({'t': 'game_msg', 'm': {'t': 'bac_write', 'r': widget.live.i('index'), 'answers': [for (final c in _c) c.text], 'done': done}});
  }

  void _changed() {
    setState(() {});
    // Sauvegarde 1 s après la dernière lettre tapée (si le temps s'arrête, rien n'est perdu)
    _save?.cancel();
    _save = Timer(const Duration(seconds: 1), _push);
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.live.s('stopBy') != null;
    final done = widget.you.yb('done');
    final full = _c.every((c) => _starts(c.text));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 44, 16, 16), children: [
      TimeBar(endsIn: widget.live.endsIn, duration: widget.live.duration, height: 8),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Lettre ', style: Pb.t(22, weight: 600, color: Pb.muted)),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Pb.yellow, shape: BoxShape.circle),
          child: Text(_letter, style: Pb.t(34, weight: 700, color: Pb.bg, height: 1)),
        ),
      ]),
      if (stop) Padding(padding: const EdgeInsets.only(top: 8), child: Text('✋ STOP ! Plus que quelques secondes !', textAlign: TextAlign.center, style: Pb.t(17, weight: 700, color: Pb.red))),
      const SizedBox(height: 12),
      for (var i = 0; i < _cats.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _c[i],
            maxLength: 30,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: i < _cats.length - 1 ? TextInputAction.next : TextInputAction.done,
            onChanged: (_) => _changed(),
            style: Pb.t(18),
            decoration: InputDecoration(
              labelText: _cats[i],
              counterText: '',
              suffixIcon: _c[i].text.isEmpty
                  ? null
                  : Icon(_starts(_c[i].text) ? Icons.check_circle_rounded : Icons.error_rounded, color: _starts(_c[i].text) ? Pb.green : Pb.yellow),
            ),
          ),
        ),
      const SizedBox(height: 6),
      FilledButton(
        onPressed: () {
          HapticFeedback.heavyImpact();
          _save?.cancel();
          _push(done: true);
        },
        child: Text(done ? 'Envoyé ✓ (tu peux corriger)' : (full && !stop ? '✋ STOP ! J’ai tout' : 'J’ai fini')),
      ),
    ]);
  }
}
