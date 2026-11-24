import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

const _vowels = 'AEIOUY';
const _blue = Color(0xFF2F6BFF);
const _opLabel = {'+': '+', '-': '−', '*': '×', '/': '÷'};

/// Réponse du serveur à un mot proposé (`cel_word_res`), reçue dans play_screen.dart
class CelWord {
  static final value = ValueNotifier<Map<String, dynamic>?>(null);
}

List<String> _letters(Map<String, dynamic> live) => [for (final l in (live['letters'] as List?) ?? const []) l as String];
List<int> _platesOf(Map<String, dynamic> live) => [for (final p in (live['plates'] as List?) ?? const []) (p as num).toInt()];

String _stepText(List s) => '${s[0]} ${_opLabel[s[1]] ?? s[1]} ${s[2]} = ${s[3]}';

/// Une lettre (jaune = consonne, rose = voyelle)
class CelTile extends StatelessWidget {
  const CelTile({super.key, this.letter, required this.size, this.dim = false});
  final String? letter;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final l = letter;
    if (l == null) {
      return Container(
        width: size,
        height: size * 1.16,
        decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(size * .18), border: Border.all(color: Pb.cardHi, width: size * .04)),
      );
    }
    final v = _vowels.contains(l);
    return Opacity(
      opacity: dim ? .22 : 1,
      child: Container(
        width: size,
        height: size * 1.16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: v ? const [Color(0xFFFFD0E6), Color(0xFFFF8CC4)] : const [Color(0xFFFFE27A), Color(0xFFF5BF12)]),
          borderRadius: BorderRadius.circular(size * .18),
          boxShadow: dim ? null : [BoxShadow(color: v ? const Color(0xFFC2407F) : const Color(0xFFB8860B), offset: Offset(0, size * .08))],
        ),
        child: Text(l, style: Pb.t(size * .62, weight: 700, color: v ? const Color(0xFF4A0F2C) : const Color(0xFF3A2A00))),
      ),
    );
  }
}

/// Une plaque de chiffres (bleue ; violette = résultat d'un calcul)
class CelPlate extends StatelessWidget {
  const CelPlate({super.key, required this.value, required this.width, this.made = false, this.selected = false});
  final int value;
  final double width;
  final bool made, selected;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: width * .74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: made ? const [Color(0xFF9B7CFF), Color(0xFF6A43E0)] : const [Color(0xFF5B8CFF), Color(0xFF2F5FE0)]),
          borderRadius: BorderRadius.circular(width * .15),
          border: Border.all(color: selected ? Pb.yellow : Colors.transparent, width: width * .05),
          boxShadow: [BoxShadow(color: made ? const Color(0xFF3D2499) : const Color(0xFF1C3A9A), offset: Offset(0, width * .06))],
        ),
        child: FittedBox(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('$value', style: Pb.t(width * .4, weight: 700, color: Colors.white)))),
      );
}

Widget _kindChip(Map<String, dynamic> live, double size) {
  final l = live.s('kind') == 'L';
  return TvChip(text: l ? '🔤 Le mot le plus long' : '🔢 Le compte est bon', size: size, bg: l ? Pb.yellow : _blue, color: l ? Pb.bg : Colors.white);
}

/// Chiffres et lettres sur la TV
class CelTv extends StatelessWidget {
  const CelTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🔢',
          title: 'Chiffres et lettres',
          sub: 'Le mot le plus long · Le compte est bon',
          rules: const [
            'Lettres : trouve le mot le plus long avec les 9 lettres (50 points par lettre).',
            'Chiffres : approche-toi le plus du nombre avec les 6 plaques (+ − × ÷).',
            'Tout se joue sur ton téléphone, le plus vite possible !',
          ],
          live: live),
      'draw' || 'ready' || 'think' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'podium' || ph == 'intro' ? ph : 'r'}-${live.i('index')}-${ph == 'reveal' ? 'rev' : ''}', child: body);
  }

  Widget _round() {
    final ph = live.phase;
    final letters = live.s('kind') == 'L';
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(label: 'Manche', index: live.i('index'), count: live.i('count'), extra: _kindChip(live, 34), live: ph == 'think' ? live : null),
        Expanded(
          child: switch ((letters, ph)) {
            (true, 'draw') => _draw(),
            (true, 'reveal') => _lettersReveal(),
            (true, _) => _lettersThink(),
            (false, 'reveal') => _numbersReveal(),
            (false, _) => _numbersThink(),
          },
        ),
      ]),
    );
  }

  Widget _tiles(double size) {
    final l = _letters(live);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < 9; i++) Padding(padding: EdgeInsets.symmetric(horizontal: size * .1), child: CelTile(letter: i < l.length ? l[i] : null, size: size)),
    ]);
  }

  Widget _draw() {
    final d = room.player(live.s('drawer') ?? '');
    final left = 9 - _letters(live).length;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (d != null) PbAvatar(size: 90, emoji: d.emoji, color: d.color, photoPath: d.photo),
        const SizedBox(width: 20),
        Text('${d?.name ?? '?'} fait le tirage…', style: Pb.t(54, weight: 600)),
      ]),
      const SizedBox(height: 60),
      _tiles(150),
      const SizedBox(height: 60),
      Text('Voyelle ou consonne ? Encore $left lettre${left > 1 ? 's' : ''}', style: Pb.t(44, color: Pb.muted)),
    ]);
  }

  Widget _lettersThink() {
    final ready = live.phase == 'ready';
    final answered = live.pids('answered');
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _tiles(170),
      const SizedBox(height: 70),
      if (ready)
        Text('À vos téléphones… partez !', style: Pb.t(60, weight: 700, color: Pb.yellow))
      else ...[
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Ont trouvé un mot :  ', style: Pb.t(40, color: Pb.muted)),
          if (answered.isEmpty) Text('personne pour l’instant', style: Pb.t(40, color: Pb.muted)) else TvAvatarRow(room: room, pids: answered, size: 70),
        ]),
        const SizedBox(height: 14),
        Text('On ne voit pas la longueur : pas de triche !', style: Pb.t(32, color: Pb.muted)),
      ],
    ]);
  }

  Widget _row({required String pid, required Widget main, required int gain, bool best = false}) {
    final p = room.player(pid);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(28), border: Border.all(color: best ? Pb.yellow : Colors.transparent, width: 5)),
      child: Row(children: [
        if (p != null) PbAvatar(size: 70, emoji: p.emoji, color: p.color, photoPath: p.photo),
        const SizedBox(width: 18),
        SizedBox(width: 260, child: Text(p?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(40, weight: 600))),
        Expanded(child: main),
        Text(gain > 0 ? '+${Pb.pts(gain)}' : '0', style: Pb.t(44, weight: 700, color: gain > 0 ? Pb.green : Pb.muted)),
      ]),
    );
  }

  Widget _list(List<Widget> rows, Widget bottom) => Column(children: [
        const SizedBox(height: 24),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text('Personne n’a répondu 😶', style: Pb.t(54, color: Pb.muted)))
              : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topCenter, child: SizedBox(width: 1760, child: Column(children: rows))),
        ),
        const SizedBox(height: 14),
        bottom,
      ]);

  Widget _lettersReveal() {
    final gains = {for (final r in live.ranking) r.pid: r.gain};
    final words = live.maps('words');
    final top = words.isEmpty ? 0 : (words.first['w'] as String).length;
    final best = [for (final w in (live['best'] as List?) ?? const []) w as String];
    return _list(
      [
        for (final w in words)
          _row(
            pid: w['pid'] as String,
            best: (w['w'] as String).length == top,
            gain: gains[w['pid']] ?? 0,
            main: Text.rich(TextSpan(children: [
              TextSpan(text: w['w'] as String, style: Pb.t(54, weight: 700).copyWith(letterSpacing: 6)),
              TextSpan(text: '   ${(w['w'] as String).length} lettres', style: Pb.t(32, color: Pb.muted)),
            ])),
          ),
      ],
      _banner(Row(children: [
        Text('💡 Le plus long possible :  ', style: Pb.t(38, color: Pb.muted)),
        if (best.isNotEmpty) Text(best.first, style: Pb.t(54, weight: 700, color: Pb.yellow).copyWith(letterSpacing: 8)),
        if (best.isNotEmpty) Text('  (${best.first.length} lettres)', style: Pb.t(34, color: Pb.muted)),
        if (best.length > 1) Flexible(child: Text('   · aussi : ${best.skip(1).join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(32, color: Pb.muted))),
      ])),
    );
  }

  Widget _banner(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
        decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(28)),
        child: child,
      );

  Widget _target(double size) => Container(
        padding: EdgeInsets.symmetric(horizontal: size * .35, vertical: size * .02),
        decoration: BoxDecoration(
          color: const Color(0xAA000000),
          borderRadius: BorderRadius.circular(size * .22),
          border: Border.all(color: Pb.cyan, width: size * .05),
          boxShadow: [BoxShadow(color: Pb.cyan.withValues(alpha: .35), blurRadius: 60)],
        ),
        child: Text('${live.i('target')}', style: Pb.t(size, weight: 700).copyWith(letterSpacing: size * .06)),
      );

  Widget _numbersThink() {
    final exact = live.pids('exact');
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _target(220),
      const SizedBox(height: 60),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final p in _platesOf(live)) Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: CelPlate(value: p, width: 200)),
      ]),
      const SizedBox(height: 60),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🎯 Ont trouvé pile :  ', style: Pb.t(40, color: Pb.muted)),
        if (exact.isEmpty) Text('personne pour l’instant', style: Pb.t(40, color: Pb.muted)) else TvAvatarRow(room: room, pids: exact, size: 70),
      ]),
    ]);
  }

  Widget _numbersReveal() {
    final gains = {for (final r in live.ranking) r.pid: r.gain};
    final res = live.maps('results');
    final sol = [for (final s in (live['solution'] as List?) ?? const []) s as List];
    final by = room.player(live.s('solutionBy') ?? '');
    return Column(children: [
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Il fallait trouver  ', style: Pb.t(44, color: Pb.muted)),
        _target(90),
      ]),
      Expanded(
        child: _list(
          [
            for (final r in res)
              _row(
                pid: r['pid'] as String,
                best: r['d'] == 0,
                gain: gains[r['pid']] ?? 0,
                main: Text.rich(TextSpan(children: [
                  TextSpan(text: '${r['v']}', style: Pb.t(54, weight: 700)),
                  TextSpan(
                    text: r['d'] == 0 ? '   🎯 le compte est bon · ${((r['ms'] as num) / 1000).toStringAsFixed(0)} s' : '   à ${r['d']}',
                    style: Pb.t(32, color: r['d'] == 0 ? Pb.green : Pb.muted),
                  ),
                ])),
              ),
          ],
          _banner(Row(children: [
            Text(by != null ? '✅ La solution de ${by.name} :  ' : '✅ Une solution :  ', style: Pb.t(34, color: Pb.muted)),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(sol.map(_stepText).join('   ·   '), style: Pb.t(38, weight: 600)),
              ),
            ),
          ])),
        ),
      ),
    ]);
  }
}

/// Chiffres et lettres sur le téléphone
class CelPlay extends StatelessWidget {
  const CelPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final String? myPid;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final letters = live.s('kind') == 'L';
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🔢', title: 'Chiffres et lettres', sub: 'Le mot le plus long et le compte est bon : tout se joue ici, sur ton téléphone !'),
      'draw' => _draw(),
      'ready' => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [_myTiles(34), const SizedBox(height: 24), Text('Prêt ?', style: Pb.t(34, weight: 700, color: Pb.yellow))])),
      'think' when letters => _CelWordPad(key: ValueKey('w${live.i('index')}'), live: live, you: you, send: send),
      'think' => _CelCalc(key: ValueKey('c${live.i('index')}'), live: live, you: you, send: send),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: ph == 'draw' ? 'draw-${live.i('index')}' : '$ph-${live.i('index')}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _myTiles(double size) {
    final l = _letters(live);
    return Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 6, children: [for (var i = 0; i < 9; i++) CelTile(letter: i < l.length ? l[i] : null, size: size)]);
  }

  Widget _draw() {
    final mine = live.s('drawer') == myPid;
    final forced = live.s('forced');
    if (!mine) {
      final d = room.player(live.s('drawer') ?? '');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _myTiles(30),
            const SizedBox(height: 26),
            Text('${d?.name ?? '?'} tire les lettres…', textAlign: TextAlign.center, style: Pb.t(24, weight: 700)),
            const SizedBox(height: 8),
            Text('Prépare-toi à chercher le mot le plus long !', textAlign: TextAlign.center, style: Pb.t(16, color: Pb.muted)),
          ]),
        ),
      );
    }
    Widget btn(String k) {
      final off = forced != null && forced != k;
      final v = k == 'v';
      return Expanded(
        child: Opacity(
          opacity: off ? .3 : 1,
          child: Material(
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: v ? const [Color(0xFFFF8CC4), Color(0xFFD6337D)] : const [Color(0xFFFFD34D), Color(0xFFE0A400)])),
              child: InkWell(
                onTap: off
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        send({'t': 'game_msg', 'm': {'t': 'cel_pick', 'k': k}});
                      },
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(v ? 'Voyelle' : 'Consonne', style: Pb.t(26, weight: 700, color: v ? Colors.white : const Color(0xFF3A2A00))),
                    Text(v ? 'A E I O U Y' : 'B C D F G…', style: Pb.t(14, color: v ? Colors.white : const Color(0xFF3A2A00))),
                  ]),
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
        Text('C’est toi qui tires !', textAlign: TextAlign.center, style: Pb.t(24, weight: 700, color: Pb.yellow)),
        const SizedBox(height: 12),
        _myTiles(29),
        const SizedBox(height: 8),
        Text(forced == null ? 'Touche pour tirer la lettre suivante' : 'Il faut encore ${forced == 'v' ? 'une voyelle' : 'une consonne'} !', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.muted)),
        const SizedBox(height: 14),
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [btn('v'), const SizedBox(width: 12), btn('c')])),
      ]),
    );
  }

  Widget _reveal() {
    final g = you.yi('gain') ?? 0;
    final letters = live.s('kind') == 'L';
    String? sub;
    if (letters) {
      final best = [for (final w in (live['best'] as List?) ?? const []) w as String];
      final mine = you.ys('word');
      sub = '${mine == null ? 'Pas de mot cette fois.' : 'Ton mot : $mine (${mine.length} lettres)'}${best.isEmpty ? '' : '\nLe plus long : ${best.first}'}';
    } else {
      final c = you?['calc'] as Map?;
      sub = c == null ? 'Pas de résultat cette fois. Il fallait ${live.i('target')}.' : (c['d'] == 0 ? 'Le compte est bon : ${c['v']} !' : 'Ton meilleur : ${c['v']} (à ${c['d']})');
    }
    return PhoneCenter(
      emoji: g > 0 ? '🎉' : '🙃',
      title: g > 0 ? 'Bien joué !' : 'Pas de points cette fois',
      color: g > 0 ? Pb.green : Pb.text,
      extra: g > 0 ? Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)) : null,
      sub: '$sub\n\n${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}

/// Lettres : on touche les lettres pour écrire son mot, puis Valider (on peut revalider plus long)
class _CelWordPad extends StatefulWidget {
  const _CelWordPad({super.key, required this.live, required this.you, required this.send});
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final void Function(Map<String, dynamic>) send;

  @override
  State<_CelWordPad> createState() => _CelWordPadState();
}

class _CelWordPadState extends State<_CelWordPad> {
  final _picked = <int>[];

  @override
  void initState() {
    super.initState();
    CelWord.value.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = _letters(widget.live);
    final mine = widget.you.ys('word');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 46, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TimeBar(endsIn: widget.live.endsIn, duration: widget.live.duration, height: 8),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (_, box) {
          final size = ((box.maxWidth - 4 * 8) / 5).clamp(36.0, 58.0);
          return Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 10, children: [
            for (var i = 0; i < l.length; i++)
              GestureDetector(
                onTap: _picked.contains(i)
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _picked.add(i));
                      },
                child: CelTile(letter: l[i], size: size * .86, dim: _picked.contains(i)),
              ),
          ]);
        }),
        const SizedBox(height: 14),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: _picked.isEmpty
              ? Text('ton mot', style: Pb.t(16, color: Pb.muted))
              : Wrap(alignment: WrapAlignment.center, spacing: 3, runSpacing: 4, children: [
                  for (final (k, i) in _picked.indexed)
                    GestureDetector(onTap: () => setState(() => _picked.removeAt(k)), child: CelTile(letter: l[i], size: 28)),
                ]),
        ),
        const SizedBox(height: 6),
        Text(_picked.isEmpty ? 'Touche les lettres (et une lettre du mot pour l’enlever)' : '${_picked.length} lettre${_picked.length > 1 ? 's' : ''}', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.muted)),
        const SizedBox(height: 6),
        ValueListenableBuilder(
          valueListenable: CelWord.value,
          builder: (_, m, _) {
            if (m == null || m['r'] != widget.live.i('index')) return const SizedBox(height: 22);
            final ok = m['ok'] == true;
            final txt = ok ? (m['kept'] == true ? '✓ ${m['w']} validé (${(m['w'] as String).length} lettres)' : '✓ ${m['w']} existe, mais tu as déjà plus long') : '✗ ${m['w']} : ${m['err']}';
            return Text(txt, textAlign: TextAlign.center, style: Pb.t(16, weight: 600, color: ok ? Pb.green : Pb.red));
          },
        ),
        const Spacer(),
        if (mine != null) Text('Ton meilleur mot : $mine', textAlign: TextAlign.center, style: Pb.t(17, weight: 700, color: Pb.yellow)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: OutlinedButton(onPressed: _picked.isEmpty ? null : () => setState(_picked.clear), child: const Text('Effacer')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Pb.green, foregroundColor: Pb.bg),
                onPressed: _picked.length < 2
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        widget.send({'t': 'game_msg', 'm': {'t': 'cel_word', 'r': widget.live.i('index'), 'w': _picked.map((i) => l[i]).join()}});
                      },
                child: Text('Valider', style: Pb.t(20, weight: 700, color: Pb.bg)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Chiffres : plaque, opération, plaque → une nouvelle plaque. Chaque calcul est envoyé au serveur.
class _CelCalc extends StatefulWidget {
  const _CelCalc({super.key, required this.live, required this.you, required this.send});
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final void Function(Map<String, dynamic>) send;

  @override
  State<_CelCalc> createState() => _CelCalcState();
}

typedef _Plate = ({int v, bool made});

class _CelCalcState extends State<_CelCalc> {
  late List<_Plate?> _plates = _start();
  final _steps = <List>[];
  final _history = <(List<_Plate?>, int)>[];
  int? _sel;
  String? _op;
  String? _err;
  bool _hideWin = false;

  List<_Plate?> _start() => [for (final p in _plates0) (v: p, made: false)];
  List<int> get _plates0 => _platesOf(widget.live);
  int get _target => widget.live.i('target');

  int? _apply(int a, String op, int b) => switch (op) {
        '+' => a + b,
        '*' => a * b,
        '-' => a > b ? a - b : null,
        '/' => b > 1 && a % b == 0 ? a ~/ b : null,
        _ => null,
      };

  void _tapPlate(int i) {
    setState(() {
      _err = null;
      if (_sel == null || _op == null || _sel == i) {
        _sel = _sel == i ? null : i;
        if (_sel == null) _op = null;
        return;
      }
      final a = _plates[_sel!]!.v, b = _plates[i]!.v;
      final r = _apply(a, _op!, b);
      if (r == null) {
        _err = _op == '-' ? 'Pas de résultat négatif ou nul' : 'La division doit tomber juste';
        return;
      }
      HapticFeedback.selectionClick();
      _history.add(([..._plates], _steps.length));
      _steps.add([a, _op, b, r]);
      _plates = [..._plates];
      _plates[_sel!] = null;
      _plates[i] = (v: r, made: true);
      _sel = null;
      _op = null;
      _hideWin = false;
    });
    widget.send({'t': 'game_msg', 'm': {'t': 'cel_calc', 'r': widget.live.i('index'), 'steps': [for (final s in _steps) s.sublist(0, 3)]}});
    if (_steps.isNotEmpty && _steps.last[3] == _target) HapticFeedback.heavyImpact();
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      final (p, n) = _history.removeLast();
      _plates = p;
      _steps.removeRange(n, _steps.length);
      _sel = null;
      _op = null;
      _err = null;
    });
  }

  void _reset() => setState(() {
        _plates = _start();
        _steps.clear();
        _history.clear();
        _sel = null;
        _op = null;
        _err = null;
      });

  @override
  Widget build(BuildContext context) {
    final calc = widget.you?['calc'] as Map?;
    final exact = calc != null && calc['d'] == 0;
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 46, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TimeBar(endsIn: widget.live.endsIn, duration: widget.live.duration, height: 8),
          const SizedBox(height: 8),
          Text('$_target', textAlign: TextAlign.center, style: Pb.t(54, weight: 700, color: Pb.cyan, height: 1.05).copyWith(letterSpacing: 3)),
          SizedBox(
            height: 22,
            child: Text(
              _err ?? (calc == null ? 'Touche une plaque, une opération, une plaque' : 'Ton meilleur : ${calc['v']} (à ${calc['d']})'),
              textAlign: TextAlign.center,
              style: Pb.t(15, weight: _err != null ? 600 : 500, color: _err != null ? Pb.red : (calc == null ? Pb.muted : Pb.yellow)),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (_, box) {
            final w = (box.maxWidth - 2 * 10) / 3;
            return Wrap(spacing: 10, runSpacing: 12, children: [
              for (var i = 0; i < _plates.length; i++)
                SizedBox(
                  width: w,
                  child: _plates[i] == null
                      ? SizedBox(height: w * .62)
                      : GestureDetector(
                          onTap: () => _tapPlate(i),
                          child: CelPlate(value: _plates[i]!.v, width: w, made: _plates[i]!.made, selected: _sel == i),
                        ),
                ),
            ].map((e) => SizedBox(height: w * .74, child: e)).toList());
          }),
          const SizedBox(height: 14),
          Row(children: [
            for (final op in ['+', '-', '*', '/'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: _op == op ? Pb.yellow : Pb.card,
                        foregroundColor: _op == op ? Pb.bg : Pb.text,
                        disabledBackgroundColor: Pb.card.withValues(alpha: .5),
                      ),
                      onPressed: _sel == null ? null : () => setState(() => _op = _op == op ? null : op),
                      child: Text(_opLabel[op]!, style: Pb.t(28, weight: 700, color: _op == op ? Pb.bg : Pb.text)),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(14)),
              child: _steps.isEmpty
                  ? Center(child: Text('Tes calculs s’affichent ici', style: Pb.t(15, color: Pb.muted)))
                  : ListView(children: [for (final s in _steps) Text(_stepText(s), style: Pb.t(17, weight: 600, height: 1.5))]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: SizedBox(height: 50, child: OutlinedButton.icon(onPressed: _history.isEmpty ? null : _undo, icon: const Icon(Icons.undo_rounded), label: const Text('Annuler')))),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 50, child: OutlinedButton(onPressed: _steps.isEmpty ? null : _reset, child: const Text('Recommencer')))),
          ]),
        ]),
      ),
      if (exact && !_hideWin)
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _hideWin = true),
            child: Container(
              color: const Color(0xEE0B3A22),
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🎯', style: TextStyle(fontSize: 80)),
                Text('Le compte est bon !', style: Pb.t(30, weight: 700, color: Pb.green)),
                const SizedBox(height: 6),
                Text('Envoyé tout seul. Touche pour revoir tes calculs.', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.text)),
              ]),
            ),
          ),
        ),
    ]);
  }
}
