import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../sfx.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import '../widgets/fireworks.dart';
import 'common_ui.dart';
import 'meninges_buzz.dart';
import 'meninges_q.dart';

/// Bataille de méninges : la question en cours du téléphone, reçue en direct (`mng_q`)
class MngLive {
  static final q = ValueNotifier<Map<String, dynamic>?>(null);
  static bool sound = true; // petits sons de mes réponses (prefs `answer_sfx`)
}

Map<String, dynamic> _catOf(Map<String, dynamic> live, String? id) {
  for (final c in (live['cats'] as List? ?? const [])) {
    if ((c as Map)['id'] == id) return c.cast<String, dynamic>();
  }
  return const {'name': '', 'emoji': '🧠', 'color': 0xFFFF4FA3};
}

Color _catColor(Map<String, dynamic> c) => Color((c['color'] as num?)?.toInt() ?? 0xFFFF4FA3);

Map<String, dynamic> _pl(Map<String, dynamic> live, String pid) => ((live['players'] as Map?)?[pid] as Map?)?.cast<String, dynamic>() ?? const {};

class _CatChip extends StatelessWidget {
  const _CatChip({required this.cat, this.size = 30, this.label});
  final Map<String, dynamic> cat;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: size * .5, vertical: size * .2),
        decoration: BoxDecoration(color: _catColor(cat), borderRadius: BorderRadius.circular(size * .5)),
        child: Text(label ?? '${cat['emoji']} ${cat['name']}', style: Pb.t(size, weight: 700, color: Colors.white)),
      );
}

/// Le cerveau, plus ou moins gros selon son poids
Widget _brain(int w, {double base = 60}) => Text('🧠', style: TextStyle(fontSize: base * (.55 + math.min(1.4, w / 1400)), height: 1));

String _g(int n) => '${Pb.pts(n)} g';

// =====================================================================================
// TV
// =====================================================================================
class MngTv extends StatelessWidget {
  const MngTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '🧠',
          title: 'Bataille de méninges',
          sub: '${live.i('count')} manches · 30 s chacune',
          rules: const [
            'À chaque manche, une épreuve éclair : réponds au plus de questions possible, à ton rythme.',
            'Les bonnes réponses font grossir ton cerveau. Enchaîne pour gagner plus !',
            'Le cerveau le plus lourd gagne.',
          ],
          live: live),
      'announce' => _announce(),
      'go' => _go(),
      'result' => _result(),
      'podium' => _MngPodiumTv(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '$ph-${live.i('index')}', child: body);
  }

  Map<String, dynamic> get _epr => (live['epr'] as Map?)?.cast<String, dynamic>() ?? const {};

  Widget _announce() {
    final e = _epr;
    final plan = live.pids('plan');
    final idx = live.i('index');
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Manche ${idx + 1} / ${live.i('count')}', style: Pb.t(44, weight: 600, color: Pb.muted)),
        const SizedBox(height: 18),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < plan.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Opacity(
                opacity: i == idx ? 1 : (i < idx ? .35 : .6),
                child: Transform.scale(scale: i == idx ? 1.25 : 1, child: _CatChip(cat: _catOf(live, plan[i]), size: 24, label: '${_catOf(live, plan[i])['emoji']}')),
              ),
            ),
        ]),
        const SizedBox(height: 30),
        _CatChip(cat: _catOf(live, e['cat'] as String?), size: 44),
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: .3, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Text(e['emoji'] as String? ?? '', style: const TextStyle(fontSize: 170)),
        ),
        Text(e['title'] as String? ?? '', style: Pb.t(96, weight: 700)),
        const SizedBox(height: 10),
        SizedBox(width: 1300, child: Text(e['desc'] as String? ?? '', textAlign: TextAlign.center, style: Pb.t(42, color: Pb.muted))),
        const SizedBox(height: 30),
        TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 120),
      ]),
    );
  }

  Widget _header({bool timer = true}) {
    final e = _epr;
    final cat = _catOf(live, e['cat'] as String?);
    return Row(children: [
      TvChip(text: 'Manche ${live.i('index') + 1} / ${live.i('count')}', color: Pb.text, size: 34),
      const SizedBox(width: 18),
      _CatChip(cat: cat, size: 32, label: '${cat['emoji']} ${cat['name']} · ${e['title'] ?? ''}'),
      const Spacer(),
      if (timer) TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 96),
    ]);
  }

  Widget _news() {
    final n = (live['news'] as Map?)?.cast<String, dynamic>();
    return SizedBox(
      height: 76,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (c, a) => SlideTransition(position: Tween(begin: const Offset(0, -.6), end: Offset.zero).animate(a), child: FadeTransition(opacity: a, child: c)),
        child: n == null
            ? const SizedBox.shrink()
            : Center(
                key: ValueKey(n['seq']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 10),
                  decoration: BoxDecoration(color: Pb.yellow, borderRadius: BorderRadius.circular(40)),
                  child: Text(
                    '${switch (n['kind']) { 'lead' => '👑', 'streak' => '🔥', 'close' => '⚔️', 'ten' => '⏱️', _ => '📣' }} ${n['text']}',
                    style: Pb.t(40, weight: 700, color: const Color(0xFF3A2A00)),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _go() {
    final players = room.players.where((p) => live['players'] is Map && (live['players'] as Map).containsKey(p.pid)).toList();
    final totals = {for (final p in players) p.pid: (_pl(live, p.pid)['total'] as num?)?.toInt() ?? 0};
    final order = [...players]..sort((a, b) => totals[b.pid]! - totals[a.pid]!);
    final rank = {for (var i = 0; i < order.length; i++) order[i].pid: i + 1};
    final maxOk = math.max(8, players.map((p) => (_pl(live, p.pid)['ok'] as num?)?.toInt() ?? 0).fold(0, math.max) + 2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 34, 60, 30),
      child: Column(children: [
        _header(),
        const SizedBox(height: 8),
        _news(),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final n = math.max(1, players.length);
            final h = math.min(150.0, (c.maxHeight - (n - 1) * 8) / n);
            return Column(children: [
              for (final p in players)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(height: h, child: _Lane(p: p, st: _pl(live, p.pid), maxOk: maxOk, rank: rank[p.pid]!, height: h)),
                ),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _result() {
    final players = room.players.where((p) => (live['players'] as Map?)?.containsKey(p.pid) ?? false).toList()
      ..sort((a, b) => ((_pl(live, b.pid)['g'] as num?) ?? 0).compareTo((_pl(live, a.pid)['g'] as num?) ?? 0));
    final last = live.i('index') >= live.i('count') - 1;
    final plan = live.pids('plan');
    final nextCat = !last && live.i('index') + 1 < plan.length ? _catOf(live, plan[live.i('index') + 1]) : null;
    final n = players.length;
    final cols = n <= 4 ? n : (n <= 8 ? 4 : 5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 34, 60, 34),
      child: Column(children: [
        _header(timer: false),
        const SizedBox(height: 6),
        _news(),
        Text('Résultat de la manche', style: Pb.t(54, weight: 700)),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final rows = (n / math.max(1, cols)).ceil();
            final w = (c.maxWidth - (cols - 1) * 20) / math.max(1, cols);
            final h = math.min(380.0, (c.maxHeight - (rows - 1) * 20) / math.max(1, rows));
            return Wrap(alignment: WrapAlignment.center, spacing: 20, runSpacing: 20, children: [
              for (var i = 0; i < n; i++) SizedBox(width: w, height: h, child: _resultCard(players[i], i, h)),
            ]);
          }),
        ),
        const SizedBox(height: 10),
        Text(nextCat == null ? 'Dernière manche terminée… place aux résultats !' : 'Manche suivante : ${nextCat['emoji']} ${nextCat['name']}', style: Pb.t(36, color: Pb.muted)),
      ]),
    );
  }

  Widget _resultCard(PlayerView p, int i, double h) {
    final st = _pl(live, p.pid);
    final g = (st['g'] as num?)?.toInt() ?? 0;
    final s = h / 380;
    return Container(
      decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(28)),
      child: Stack(children: [
        if (i < 3 && g > 0) Positioned(top: 10, right: 14, child: Text(['🥇', '🥈', '🥉'][i], style: TextStyle(fontSize: 54 * s))),
        Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                PbAvatar(size: 84, emoji: p.emoji, color: p.color, photoPath: p.photo),
                const SizedBox(height: 6),
                Text(p.name, style: Pb.t(38, weight: 700)),
                SizedBox(height: 130, child: Center(child: _brain((st['w'] as num?)?.toInt() ?? 500, base: 100))),
                Text('+${_g(g)}', style: Pb.t(48, weight: 700, color: g > 0 ? Pb.green : Pb.muted)),
                Text('${st['ok'] ?? 0} justes · ${st['ko'] ?? 0} erreurs', style: Pb.t(28, color: Pb.muted)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Une ligne de la course : avatar, barre des bonnes réponses, ✓/✗ qui clignote, poids du cerveau
class _Lane extends StatefulWidget {
  const _Lane({required this.p, required this.st, required this.maxOk, required this.rank, required this.height});
  final PlayerView p;
  final Map<String, dynamic> st;
  final int maxOk, rank;
  final double height;

  @override
  State<_Lane> createState() => _LaneState();
}

class _LaneState extends State<_Lane> {
  String _flash = '';
  Timer? _t;

  @override
  void didUpdateWidget(_Lane old) {
    super.didUpdateWidget(old);
    final ok = widget.st['ok'] ?? 0, ko = widget.st['ko'] ?? 0;
    if ((old.st['ko'] ?? 0) != ko && ko != 0) {
      _show('✗');
    } else if ((old.st['ok'] ?? 0) != ok && ok != 0) {
      _show('✓');
    }
  }

  void _show(String s) {
    _t?.cancel();
    setState(() => _flash = s);
    _t = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flash = '');
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final ok = (st['ok'] as num?)?.toInt() ?? 0;
    final streak = (st['streak'] as num?)?.toInt() ?? 0;
    final w = (st['w'] as num?)?.toInt() ?? 500;
    final h = widget.height;
    final color = Pb.playerColor(widget.p.color);
    final s = (h / 110).clamp(.45, 1.0);
    return Row(children: [
      SizedBox(width: 64 * s, child: Text((st['total'] as num? ?? 0) > 0 ? '${widget.rank}' : '', textAlign: TextAlign.center, style: Pb.t(44 * s, weight: 700, color: widget.rank == 1 ? Pb.yellow : Pb.muted))),
      PbAvatar(size: h * .8, emoji: widget.p.emoji, color: widget.p.color, photoPath: widget.p.photo, dimmed: !widget.p.connected),
      const SizedBox(width: 14),
      SizedBox(width: 230 * s + 40, child: Text(widget.p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(42 * s, weight: 700))),
      Expanded(
        child: Container(
          height: h * .62,
          decoration: BoxDecoration(color: Pb.bg2, borderRadius: BorderRadius.circular(h)),
          child: LayoutBuilder(builder: (context, c) {
            return Stack(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                width: math.max(h * .62, c.maxWidth * ok / widget.maxOk),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h),
                  gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, .45)!]),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18 * s),
                  child: Row(children: [
                    Text('Q ${(st['done'] as num?)?.toInt() ?? 0}', style: Pb.t(30 * s, weight: 600, color: Colors.white.withValues(alpha: .85))),
                    const Spacer(),
                    if (streak >= 3) Text('🔥 ×$streak  ', style: Pb.t(32 * s, weight: 700)),
                    Text('$ok ✓', style: Pb.t(34 * s, weight: 700)),
                  ]),
                ),
              ),
            ]);
          }),
        ),
      ),
      SizedBox(
        width: 64 * s,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _flash.isEmpty ? 0 : 1,
          child: Text(_flash, textAlign: TextAlign.center, style: Pb.t(54 * s, weight: 700, color: _flash == '✗' ? Pb.red : Pb.green)),
        ),
      ),
      SizedBox(width: 190 * s, child: Text(_g(w), textAlign: TextAlign.right, style: Pb.t(38 * s, weight: 700, color: Pb.yellow))),
      SizedBox(width: 100 * s, height: h, child: Center(child: _brain(w, base: 64 * s))),
    ]);
  }
}

/// Le poids des cerveaux : du plus léger au plus lourd, puis le podium et les médailles
class _MngPodiumTv extends StatefulWidget {
  const _MngPodiumTv({required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  State<_MngPodiumTv> createState() => _MngPodiumTvState();
}

class _MngPodiumTvState extends State<_MngPodiumTv> {
  int _shown = 0;
  Timer? _t;

  List<PlayerView> get _players {
    final live = widget.live;
    final l = widget.room.players.where((p) => (live['players'] as Map?)?.containsKey(p.pid) ?? false).toList()
      ..sort((a, b) => ((_pl(live, a.pid)['w'] as num?) ?? 0).compareTo((_pl(live, b.pid)['w'] as num?) ?? 0));
    return l; // du plus léger au plus lourd
  }

  @override
  void initState() {
    super.initState();
    final elapsed = widget.live.duration - widget.live.endsIn;
    _shown = (elapsed / 1600).floor().clamp(0, 99);
    _t = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _shown++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final asc = _players;
    final n = asc.length;
    // les derniers d'abord, d'un coup s'ils sont nombreux ; les 5 premiers un par un
    final quick = math.max(0, n - 5);
    final visible = math.min(n, quick + _shown);
    final done = visible >= n;
    final desc = asc.reversed.toList();
    final medals = (live['medals'] as Map?)?.cast<String, dynamic>() ?? const {};
    int w(PlayerView p) => (_pl(live, p.pid)['w'] as num?)?.toInt() ?? 500;
    bool seen(PlayerView p) => asc.indexOf(p) < visible;
    List<String> medalsOf(PlayerView p) => [for (final e in medals.entries) if (e.value == p.pid) '${_catOf(live, e.key)['emoji']}'];

    Widget pod(int place) {
      if (place >= desc.length) return const SizedBox(width: 330);
      final p = desc[place];
      final show = seen(p);
      final heights = [300.0, 220.0, 160.0];
      final cols = [const [Color(0xFFFFE066), Color(0xFFE0A800)], const [Color(0xFFCFD3E6), Color(0xFF8D93AD)], const [Color(0xFFF3B07A), Color(0xFFB8682E)]];
      return SizedBox(
        width: 330,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: show ? 1 : .0,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            _brain(w(p), base: place == 0 ? 150 : 110),
            PbAvatar(size: place == 0 ? 120 : 96, emoji: p.emoji, color: p.color, photoPath: p.photo),
            const SizedBox(height: 6),
            Text(p.name, style: Pb.t(42, weight: 700)),
            Text(_g(w(p)), style: Pb.t(46, weight: 700, color: Pb.yellow)),
            Text(medalsOf(p).join(' '), style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Container(
              height: heights[place],
              decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: cols[place])),
              alignment: Alignment.center,
              child: Text('${place + 1}', style: Pb.t(90, weight: 700, color: Colors.black54)),
            ),
          ]),
        ),
      );
    }

    final others = desc.length > 3 ? desc.sublist(3) : <PlayerView>[];
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(60, 36, 60, 0),
        child: Column(children: [
          Text('⚖️ Le poids des cerveaux', style: Pb.t(76, weight: 700)),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // les autres places
              SizedBox(
                width: 380,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (var i = 0; i < others.length; i++)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: seen(others[i]) ? 1 : 0,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                SizedBox(width: 50, child: Text('${i + 4}.', style: Pb.t(32, weight: 700, color: Pb.muted))),
                                PbAvatar(size: 50, emoji: others[i].emoji, color: others[i].color, photoPath: others[i].photo),
                                const SizedBox(width: 10),
                                Text(others[i].name, style: Pb.t(32, weight: 600)),
                                const SizedBox(width: 14),
                                Text(_g(w(others[i])), style: Pb.t(32, weight: 700, color: Pb.yellow)),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [pod(1), const SizedBox(width: 24), pod(0), const SizedBox(width: 24), pod(2)]),
              ),
              // médailles par catégorie
              SizedBox(
                width: 380,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 500),
                      opacity: done ? 1 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(24)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text('🏅 Médailles', style: Pb.t(36, weight: 700)),
                          const SizedBox(height: 8),
                          for (final e in medals.entries)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('${_catOf(live, e.key)['emoji']} ${_catOf(live, e.key)['name']} : ${widget.room.player(e.value as String)?.name ?? '?'}', style: Pb.t(28, color: Pb.text)),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
      if (done) const Positioned.fill(child: IgnorePointer(child: Fireworks())),
    ]);
  }
}

// =====================================================================================
// Téléphone
// =====================================================================================
class MngPlay extends StatefulWidget {
  const MngPlay({super.key, required this.room, required this.live, required this.you, required this.isHost, required this.send});
  final RoomView room;
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final bool isHost;
  final void Function(Map<String, dynamic>) send;

  @override
  State<MngPlay> createState() => _MngPlayState();
}

class _MngPlayState extends State<MngPlay> {
  String _feedback = ''; // ✅ / ❌ par-dessus la question
  String _correction = '';
  Timer? _fbTimer;
  DateTime _lockedUntil = DateTime.now();
  int _lastSeen = -1;

  @override
  void initState() {
    super.initState();
    if (MngLive.sound) Sfx.instance.init();
    MngLive.q.addListener(_onQ);
  }

  @override
  void dispose() {
    MngLive.q.removeListener(_onQ);
    _fbTimer?.cancel();
    super.dispose();
  }

  // Une question arrive : on montre si la précédente était juste
  void _onQ() {
    final m = MngLive.q.value;
    if (m == null || !mounted) return;
    final last = (m['last'] as Map?)?.cast<String, dynamic>();
    final wait = (m['wait'] as num?)?.toInt() ?? 0;
    if (last != null && (last['i'] as num?)?.toInt() != _lastSeen) {
      _lastSeen = (last['i'] as num?)?.toInt() ?? -1;
      final ok = last['ok'] == true;
      if (MngLive.sound) Sfx.instance.play(ok ? 'ding' : 'buzz', vol: .5);
      mngBuzz(ok);
      _fbTimer?.cancel();
      setState(() {
        _feedback = ok ? '✅' : '❌';
        _correction = ok ? '+${last['g'] ?? 0} g' : _answerText(last);
        _lockedUntil = DateTime.now().add(Duration(milliseconds: wait));
      });
      _fbTimer = Timer(Duration(milliseconds: ok ? 350 : math.max(600, wait)), () {
        if (mounted) setState(() => _feedback = '');
      });
    } else {
      setState(() {});
    }
  }

  String _answerText(Map<String, dynamic> last) {
    if (last['num'] != null) return 'C’était ${last['num']}';
    if (last['text'] != null) return 'C’était ${last['text']}';
    return 'Raté !';
  }

  // La question en cours : la plus récente entre le message direct et l'état du salon
  Map<String, dynamic>? get _q {
    final r = widget.live.i('index');
    final m = MngLive.q.value;
    final fromMsg = m != null && (m['r'] as num?)?.toInt() == r ? (m['q'] as Map?)?.cast<String, dynamic>() : null;
    final fromState = (widget.you?['q'] as Map?)?.cast<String, dynamic>();
    if (fromMsg == null) return fromState;
    if (fromState == null) return fromMsg;
    return ((fromState['i'] as num?) ?? 0) > ((fromMsg['i'] as num?) ?? 0) ? fromState : fromMsg;
  }

  Map<String, dynamic> get _me {
    final m = MngLive.q.value;
    final r = widget.live.i('index');
    final y = widget.you ?? const {};
    if (m != null && (m['r'] as num?)?.toInt() == r && ((m['q'] as Map?)?['i'] as num? ?? -1) >= ((y['q'] as Map?)?['i'] as num? ?? -1)) {
      return {...y, 'ok': m['ok'], 'ko': m['ko'], 'streak': m['streak'], 'g': m['g']};
    }
    return y;
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final ph = live.phase;
    final e = (live['epr'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cat = _catOf(live, e['cat'] as String?);
    final Widget body = switch (ph) {
      'intro' => const PhoneCenter(emoji: '🧠', title: 'Bataille de méninges', sub: 'Des épreuves éclair de 30 s : réponds au plus de questions possible, à ton rythme !'),
      'announce' => PhoneCenter(
          emoji: e['emoji'] as String? ?? '🧠',
          title: e['title'] as String? ?? '',
          sub: e['desc'] as String?,
          extra: Column(children: [
            _CatChip(cat: cat, size: 18),
            const SizedBox(height: 16),
            TimeCircle(endsIn: live.endsIn, duration: live.duration, size: 70),
          ]),
        ),
      'go' => _go(cat, e),
      'result' => _result(),
      'podium' => _podium(),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: '$ph-${live.i('index')}', isHost: widget.isHost, phase: ph, send: widget.send, skipLabel: 'Manche suivante', child: body);
  }

  Widget _go(Map<String, dynamic> cat, Map<String, dynamic> e) {
    final q = _q;
    final me = _me;
    final streak = (me['streak'] as num?)?.toInt() ?? 0;
    final locked = DateTime.now().isBefore(_lockedUntil);
    if (locked) {
      Future<void>.delayed(_lockedUntil.difference(DateTime.now()) + const Duration(milliseconds: 20), () {
        if (mounted) setState(() {});
      });
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 40, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _CatChip(cat: cat, size: 15, label: '${cat['emoji']} ${e['title'] ?? ''}'))),
          const Spacer(),
          if (streak >= 3) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Pb.yellow, borderRadius: BorderRadius.circular(20)),
            child: Text('🔥 ×$streak', style: Pb.t(15, weight: 700, color: const Color(0xFF3A2A00))),
          ),
        ]),
        const SizedBox(height: 8),
        TimeBar(endsIn: widget.live.endsIn, duration: widget.live.duration, height: 7),
        const SizedBox(height: 4),
        Row(children: [
          Text('✓ ${me['ok'] ?? 0}', style: Pb.t(16, weight: 700, color: Pb.green)),
          const SizedBox(width: 12),
          Text('✗ ${me['ko'] ?? 0}', style: Pb.t(16, weight: 700, color: Pb.red)),
          const Spacer(),
          Text('+${_g((me['g'] as num?)?.toInt() ?? 0)}', style: Pb.t(16, weight: 700, color: Pb.yellow)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(children: [
            Positioned.fill(
              child: q == null
                  ? const Center(child: CircularProgressIndicator())
                  : MngQuestion(
                      key: ValueKey('${widget.live.i('index')}-${q['i']}'),
                      q: q,
                      locked: locked,
                      onAnswer: (v) => widget.send({'t': 'game_msg', 'm': {'t': 'mng_answer', 'r': widget.live.i('index'), 'i': q['i'], 'v': v}}),
                    ),
            ),
            if (_feedback.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: _feedback == '❌' ? Pb.bg.withValues(alpha: .75) : Colors.transparent,
                    alignment: Alignment.center,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: .5, end: 1),
                        duration: const Duration(milliseconds: 250),
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: Text(_feedback, style: const TextStyle(fontSize: 110)),
                      ),
                      Text(_correction, style: Pb.t(26, weight: 700, color: _feedback == '❌' ? Pb.text : Pb.green)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _result() {
    final y = widget.you ?? const {};
    final g = (y['g'] as num?)?.toInt() ?? 0;
    return PhoneCenter(
      emoji: '🧠',
      title: g > 0 ? '+${_g(g)}' : 'Pas de grammes cette fois',
      color: g > 0 ? Pb.green : Pb.text,
      sub: '${y['ok'] ?? 0} justes · ${y['ko'] ?? 0} erreurs\nMon cerveau : ${_g((y['w'] as num?)?.toInt() ?? 500)}',
    );
  }

  Widget _podium() {
    final y = widget.you ?? const {};
    final live = widget.live;
    final rank = (y['total'] as num? ?? 0) > 0 ? (y['rank'] as num?)?.toInt() : null;
    final cats = (y['cat'] as Map?)?.cast<String, dynamic>() ?? const {};
    final played = {for (final c in live.pids('plan')) c};
    final best = cats.entries.isEmpty ? null : cats.entries.reduce((a, b) => (a.value as num) >= (b.value as num) ? a : b);
    final view = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _brain((y['w'] as num?)?.toInt() ?? 500, base: 100),
          Text(_g((y['w'] as num?)?.toInt() ?? 500), style: Pb.t(40, weight: 700, color: Pb.yellow)),
          Text(rank == null ? 'Fin de la partie' : '${rank == 1 ? '1re' : '${rank}e'} place !', style: Pb.t(28, weight: 700, color: rank == 1 ? Pb.yellow : Pb.text)),
          if (best != null) Text('Ton point fort : ${_catOf(live, best.key)['emoji']} ${_catOf(live, best.key)['name']}', style: Pb.t(17, color: Pb.muted)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              for (final c in (live['cats'] as List? ?? const []).cast<Map>())
                if (played.contains(c['id']))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Text('${c['emoji']} ${c['name']}', style: Pb.t(17)),
                      const Spacer(),
                      Text(_g((cats[c['id']] as num?)?.toInt() ?? 0), style: Pb.t(17, weight: 700)),
                    ]),
                  ),
              const Divider(),
              Row(children: [
                Text('🔥 Meilleure série', style: Pb.t(17)),
                const Spacer(),
                Text('${y['best'] ?? 0}', style: Pb.t(17, weight: 700)),
              ]),
            ]),
          ),
        ]),
      ),
    );
    if (rank != 1) return view;
    return Stack(children: [view, const Positioned.fill(child: IgnorePointer(child: Fireworks(seconds: 5)))]);
  }
}
