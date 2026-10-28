import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../net.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/countdown.dart';
import 'common_ui.dart';
import 'kit_ui.dart';

/// La photo de la manche, en grand (servie par le serveur, jamais gardée en base)
class PhrPhoto extends StatelessWidget {
  const PhrPhoto({super.key, required this.path, this.radius = 36});
  final String? path;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Pb.cardHi, width: radius * .1),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? const SizedBox.expand()
          : Image.network(
              photoUrl(path!),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const Center(child: Text('📸', style: TextStyle(fontSize: 80))),
            ),
    );
  }
}

/// Photo roulette sur la TV
class PhrTv extends StatelessWidget {
  const PhrTv({super.key, required this.room, required this.live});
  final RoomView room;
  final Map<String, dynamic> live;

  @override
  Widget build(BuildContext context) {
    final ph = live.phase;
    final Widget body = switch (ph) {
      'intro' => TvIntro(
          emoji: '📸',
          title: 'Photo roulette',
          sub: '${live.i('per', 4)} photos chacun',
          rules: const [
            'Chacun choisit des photos sur son téléphone (celles que tu veux bien montrer 😉).',
            'Puis devine à qui est chaque photo. Son propriétaire, lui, ne dit rien !',
          ],
          live: live),
      'pick' => _pick(),
      'ask' || 'reveal' => _round(),
      'podium' => TvPodium(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
    return TvSwitcher(stepKey: '${ph == 'reveal' ? 'ask' : ph}-${live.i('index')}', child: body);
  }

  Widget _pick() => Padding(
        padding: const EdgeInsets.fromLTRB(80, 60, 80, 50),
        child: Column(children: [
          const Spacer(),
          const Text('🖼️🤫', style: TextStyle(fontSize: 150)),
          Text('Choisissez vos photos', style: Pb.t(84, weight: 700)),
          const SizedBox(height: 12),
          Text('${live.i('per', 4)} chacun, sur votre téléphone, sans les montrer !', style: Pb.t(44, color: Pb.muted)),
          const Spacer(),
          TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
          const SizedBox(height: 26),
          SizedBox(height: 90, child: TvWhoDone(room: room, done: live.pids('done').toSet(), label: 'sont prêts')),
        ]),
      );

  Widget _round() {
    final reveal = live.phase == 'reveal';
    final owner = reveal ? room.player(live.s('owner') ?? '') : null;
    final picks = {for (final e in ((live['picks'] as Map?) ?? const {}).entries) e.key as String: e.value as String};
    final found = [for (final e in picks.entries) if (e.value == live.s('owner')) e.key];
    // Pendant le vote : seulement le nombre de votes (montrer qui a voté trahirait le propriétaire)
    final votes = live.pids('answered').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvHeader(
          label: 'Photo',
          index: live.i('index'),
          count: live.i('count'),
          live: reveal ? null : live,
          extra: reveal ? null : TvChip(text: '$votes vote${votes > 1 ? 's' : ''}', size: 34),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 6, child: PhrPhoto(path: live.s('photo'))),
            const SizedBox(width: 50),
            Expanded(
              flex: 4,
              child: Center(
                child: reveal && owner != null
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        PbAvatar(size: 220, emoji: owner.emoji, color: owner.color, photoPath: owner.photo),
                        const SizedBox(height: 20),
                        Text('C’était à ${owner.name} !', textAlign: TextAlign.center, style: Pb.t(70, weight: 700, color: Pb.yellow, height: 1.1)),
                        const SizedBox(height: 16),
                        if (found.isEmpty)
                          Text('Personne n’a trouvé 😏', style: Pb.t(42, color: Pb.muted))
                        else ...[
                          Text('Trouvé par', style: Pb.t(38, color: Pb.muted)),
                          const SizedBox(height: 8),
                          TvAvatarRow(room: room, pids: found, size: 70),
                        ],
                      ])
                    : Text('À qui est\ncette photo ? 🤔', textAlign: TextAlign.center, style: Pb.t(76, weight: 700, height: 1.15)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        if (reveal) SizedBox(height: 90, child: TvGains(room: room, ranking: live.ranking)),
        if (!reveal) TimeBar(endsIn: live.endsIn, duration: live.duration, height: 16),
      ]),
    );
  }
}

/// Photo roulette sur le téléphone
class PhrPlay extends StatelessWidget {
  const PhrPlay({super.key, required this.room, required this.live, required this.you, required this.myPid, required this.isHost, required this.send});
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
      'intro' => PhoneCenter(
          emoji: '📸',
          title: 'Photo roulette',
          sub: 'Prépare-toi à choisir ${live.i('per', 4)} photos de ton téléphone. Ne les montre à personne !'),
      'pick' => _PhrPick(key: const ValueKey('pick'), live: live, you: you, send: send),
      'ask' => _ask(),
      'reveal' => _reveal(),
      'podium' => phoneRank(you),
      _ => const SizedBox.shrink(),
    };
    return PhoneGameFrame(stepKey: ph == 'pick' ? 'pick' : '$ph-${live.i('index')}-${you?['answer']}', isHost: isHost, phase: ph, send: send, child: body);
  }

  Widget _ask() {
    if (you.yb('mine')) {
      return const PhoneCenter(emoji: '🤫', title: 'C’est ta photo !', sub: 'Fais comme si de rien n’était… Si les autres se trompent, tu gagnes des points.');
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 44, 16, 16), children: [
      TimeBar(endsIn: live.endsIn, duration: live.duration, height: 8),
      const SizedBox(height: 12),
      Text(you.ys('answer') == null ? 'À qui est la photo sur la TV ?' : 'Vote envoyé ! Regarde la TV 📺',
          textAlign: TextAlign.center, style: Pb.t(19, weight: 700, color: you.ys('answer') == null ? Pb.text : Pb.green)),
      const SizedBox(height: 12),
      PhonePlayerPick(
        room: room,
        myPid: myPid,
        picked: you.ys('answer'),
        onPick: (pid) => send({'t': 'game_msg', 'm': {'t': 'phr_guess', 'r': live.i('index'), 'pid': pid}}),
      ),
    ]);
  }

  Widget _reveal() {
    final owner = room.player(live.s('owner') ?? '');
    final g = you.yi('gain') ?? 0;
    final mine = live.s('owner') == myPid;
    return PhoneCenter(
      emoji: mine ? '😎' : (g > 0 ? '🎯' : '🙈'),
      title: mine ? 'C’était ta photo !' : 'C’était à ${owner?.name ?? '?'}',
      color: g > 0 ? Pb.green : Pb.text,
      extra: g > 0 ? Text('+${Pb.pts(g)}', style: Pb.t(46, weight: 700, color: Pb.green)) : null,
      sub: '${Pb.pts(you.yi('score') ?? 0)} points au total',
    );
  }
}

/// Choix des photos : galerie du téléphone, photos réduites puis envoyées une par une
class _PhrPick extends StatefulWidget {
  const _PhrPick({super.key, required this.live, required this.you, required this.send});
  final Map<String, dynamic> live;
  final Map<String, dynamic>? you;
  final void Function(Map<String, dynamic>) send;

  @override
  State<_PhrPick> createState() => _PhrPickState();
}

class _PhrPickState extends State<_PhrPick> {
  final List<Uint8List> _thumbs = []; // ce qu'on a envoyé (affiché ici seulement)
  bool _busy = false;
  String? _error;

  int get _per => widget.live.i('per', 4);
  int get _sent => widget.you.yi('sent') ?? _thumbs.length;
  bool get _done => widget.you.yb('done');

  // Photo réduite à ~1000 px, JPEG ≤ 200 Ko (le serveur refuse au-delà de 220 Ko)
  static Uint8List? _shrink(Uint8List bytes) {
    if (bytes.length <= 200 * 1024 && bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return bytes;
    final d = img.decodeImage(bytes);
    if (d == null) return null;
    var im = img.bakeOrientation(d);
    for (final (size, q) in const [(1000, 75), (800, 65), (600, 55)]) {
      final r = im.width >= im.height ? img.copyResize(im, width: size) : img.copyResize(im, height: size);
      final out = Uint8List.fromList(img.encodeJpg(r, quality: q));
      if (out.length <= 200 * 1024) return out;
      im = r;
    }
    return null;
  }

  Future<void> _add() async {
    final left = _per - _sent;
    if (left <= 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await ImagePicker().pickMultiImage(maxWidth: 1000, maxHeight: 1000, imageQuality: 75, limit: left > 1 ? left : null);
      for (final f in files.take(left)) {
        final small = _shrink(await f.readAsBytes());
        if (small == null) {
          _error = 'Une photo n’a pas pu être lue';
          continue;
        }
        widget.send({'t': 'game_msg', 'm': {'t': 'phr_photo', 'data': base64Encode(small)}});
        _thumbs.add(small);
        if (mounted) setState(() {});
      }
    } catch (_) {
      _error = 'Impossible d’ouvrir la galerie';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _clear() {
    HapticFeedback.selectionClick();
    widget.send({'t': 'game_msg', 'm': {'t': 'phr_clear'}});
    setState(() => _thumbs.clear());
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    widget.send({'t': 'game_msg', 'm': {'t': 'phr_done'}});
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sent;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 44, 18, 18), children: [
      TimeBar(endsIn: widget.live.endsIn, duration: widget.live.duration, height: 8),
      const SizedBox(height: 14),
      Text('📸 Choisis $_per photos', textAlign: TextAlign.center, style: Pb.t(24, weight: 700)),
      const SizedBox(height: 4),
      Text('Des photos que tu veux bien montrer à tout le monde 😉\nElles sont effacées à la fin de la partie.',
          textAlign: TextAlign.center, style: Pb.t(15, color: Pb.muted)),
      const SizedBox(height: 16),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (var i = 0; i < _per; i++)
            Container(
              decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: i < _thumbs.length
                  ? Image.memory(_thumbs[i], fit: BoxFit.cover)
                  : Center(
                      child: i < sent
                          ? const Icon(Icons.check_circle_rounded, color: Pb.green, size: 36)
                          : Text('${i + 1}', style: Pb.t(28, weight: 700, color: Pb.muted)),
                    ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (_error != null) Text(_error!, textAlign: TextAlign.center, style: Pb.t(15, color: Pb.red)),
      if (_done)
        Text('C’est envoyé ! On attend les autres… 🤫', textAlign: TextAlign.center, style: Pb.t(18, weight: 600, color: Pb.green))
      else ...[
        FilledButton.icon(
          onPressed: _busy || sent >= _per ? null : _add,
          icon: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
              : const Icon(Icons.photo_library_rounded),
          label: Text(sent == 0 ? 'Choisir mes photos' : 'Ajouter (${_per - sent} de plus)'),
        ),
        if (sent > 0) ...[
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _finish, child: Text('J’ai fini ($sent photo${sent > 1 ? 's' : ''})')),
        ],
      ],
      if (sent > 0) TextButton(onPressed: _clear, child: Text('Recommencer', style: Pb.t(15, color: Pb.muted))),
    ]);
  }
}
