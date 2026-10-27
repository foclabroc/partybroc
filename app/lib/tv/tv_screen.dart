import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/dessin_ui.dart';
import '../games/draw_board.dart';
import '../games/droles_ui.dart';
import '../games/quidenous_ui.dart';
import '../games/quiz_state.dart';
import '../games/reflexes_ui.dart';
import '../games/quiz_tv.dart';
import '../models.dart';
import '../music.dart';
import '../net.dart';
import '../theme.dart';
import '../widgets/avatar.dart';

/// Écran de la TV : code + QR à gauche, joueurs à droite, jeux en bas.
/// Tout est dessiné sur une toile 1920×1080 mise à l'échelle de l'écran.
class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  late final PbSocket _sock;
  StreamSubscription? _sub;
  SharedPreferences? _prefs;
  RoomView? _room;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sock = PbSocket(onOpen: _hello);
    _sub = _sock.messages.listen(_onMessage);
    DrawBoard.instance.requestSync = () => _sock.send({'t': 'tv_game_msg', 'm': {'t': 'drw_sync'}});
    SharedPreferences.getInstance().then((p) {
      _prefs = p;
      _sock.connect();
    });
    Music.instance.init().then((_) {
      if (mounted) setState(() {});
      Music.instance.play('salon');
    });
  }

  void _hello(PbSocket s) {
    s.send({
      't': 'tv_hello',
      'code': _prefs?.getString('tv_code'),
      'tvToken': _prefs?.getString('tv_token'),
    });
  }

  void _onMessage(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'tv_ok':
        _prefs?.setString('tv_code', m['code'] as String);
        _prefs?.setString('tv_token', m['tvToken'] as String);
      case 'room':
        setState(() {
          _room = RoomView.fromJson(m['room'] as Map<String, dynamic>);
          _error = null;
        });
        // Musique : « jeu » pendant une partie, « salon » au salon et au podium
        final live = _room!.live;
        Music.instance.play(live != null && live['phase'] != 'podium' ? 'jeu' : 'salon');
      case 'closed':
        // Salon fermé côté serveur : on en ouvre un neuf
        _prefs?.remove('tv_code');
        _prefs?.remove('tv_token');
        setState(() => _room = null);
        _hello(_sock);
      case 'draw':
        DrawBoard.instance.apply(m);
      case 'replaced':
        setState(() => _error = 'Ce salon est maintenant affiché sur un autre écran.');
      case 'error':
        setState(() => _error = m['msg'] as String?);
    }
  }

  Widget _game(RoomView room) {
    final live = room.live!;
    return switch (live['id']) {
      'quiz' => QuizTv(room: room, q: QuizState.fromJson(live)),
      'quidenous' => QdnTv(room: room, live: live),
      'droles' => DrlTv(room: room, live: live),
      'reflexes' => RfxTv(room: room, live: live),
      'dessin' => DsnTv(room: room, live: live),
      _ => const SizedBox.shrink(),
    };
  }

  void _newRoom() {
    _prefs?.remove('tv_code');
    _prefs?.remove('tv_token');
    _sock.send({'t': 'tv_new'});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dans un navigateur, le son ne démarre qu'après un premier appui
    return Listener(
      onPointerDown: (_) => Music.instance.unlock(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, _) {
          Music.instance.unlock();
          return KeyEventResult.ignored;
        },
        child: _scaffold(),
      ),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      body: PartyBackground(
        child: Center(
          child: FittedBox(
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: Stack(children: [
                if (_room == null)
                  Center(child: _waiting())
                else if (_room!.live != null)
                  _game(_room!)
                else
                  _Lobby(room: _room!, onNewRoom: _newRoom),
                Positioned(top: 30, left: 0, right: 0, child: Center(child: _NetBadge(state: _sock.state))),
                if (_error != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40,
                    child: Center(child: _toast(_error!)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _waiting() => Column(mainAxisSize: MainAxisSize.min, children: [
        const PbLogo(size: 110),
        const SizedBox(height: 40),
        const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 6, color: Pb.pink)),
        const SizedBox(height: 30),
        Text('Ouverture du salon…', style: Pb.t(40, color: Pb.muted)),
      ]);

  Widget _toast(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
        decoration: BoxDecoration(color: Pb.cardHi, borderRadius: BorderRadius.circular(24)),
        child: Text(msg, style: Pb.t(32)),
      );
}

class _Lobby extends StatelessWidget {
  const _Lobby({required this.room, required this.onNewRoom});
  final RoomView room;
  final VoidCallback onNewRoom;

  @override
  Widget build(BuildContext context) {
    final base = serverBase();
    final joinUrl = base.replace(path: '/play', queryParameters: {'code': room.code}).toString();
    final shortUrl = '${base.host}${base.hasPort && base.port != 443 && base.port != 80 ? ':${base.port}' : ''}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 46, 80, 46),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PbLogo(size: 64),
          const Spacer(),
          const _MusicButton(),
          const SizedBox(width: 20),
          TextButton.icon(
            onPressed: onNewRoom,
            icon: const Icon(Icons.refresh_rounded, size: 30, color: Pb.muted),
            label: Text('Nouveau salon', style: Pb.t(26, color: Pb.muted)),
          ),
        ]),
        const SizedBox(height: 26),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ---- Rejoindre ----
            SizedBox(
              width: 540,
              child: Container(
                padding: const EdgeInsets.fromLTRB(36, 30, 36, 34),
                decoration: BoxDecoration(
                  color: Pb.card.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Pb.cardHi, width: 3),
                ),
                child: Column(children: [
                  Text('Scanne pour jouer', style: Pb.t(38, weight: 600)),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                    child: QrImageView(
                      data: joinUrl,
                      size: 250,
                      padding: EdgeInsets.zero,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Pb.bg),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle, color: Pb.bg),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: 'ou va sur ', style: Pb.t(26, color: Pb.muted)),
                    TextSpan(text: shortUrl, style: Pb.t(28, weight: 600, color: Pb.cyan)),
                  ])),
                  Text('avec le code', style: Pb.t(26, color: Pb.muted)),
                  const Spacer(),
                  _CodeLetters(code: room.code),
                ]),
              ),
            ),
            const SizedBox(width: 70),
            // ---- Joueurs ----
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Joueurs', style: Pb.t(48, weight: 700)),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                    decoration: BoxDecoration(color: Pb.cardHi, borderRadius: BorderRadius.circular(40)),
                    child: Text('${room.players.length} / ${room.maxPlayers}', style: Pb.t(34, weight: 600)),
                  ),
                ]),
                const SizedBox(height: 34),
                Expanded(child: _PlayersGrid(room: room)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 26),
        _GamesStrip(room: room),
      ]),
    );
  }
}

class _CodeLetters extends StatelessWidget {
  const _CodeLetters({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (final ch in code.split(''))
        Container(
          width: 84,
          height: 96,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Pb.yellow,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Pb.yellow.withValues(alpha: .4), blurRadius: 24)],
          ),
          child: Text(ch, style: Pb.t(64, weight: 700, color: Pb.bg, height: 1)),
        ),
    ]);
  }
}

class _PlayersGrid extends StatelessWidget {
  const _PlayersGrid({required this.room});
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    const perRow = 5;
    final slots = room.maxPlayers;
    return Wrap(
      spacing: 26,
      runSpacing: 34,
      children: [
        for (var i = 0; i < slots; i++)
          SizedBox(
            width: 196,
            child: i < room.players.length
                ? _PlayerTile(key: ValueKey(room.players[i].pid), p: room.players[i], host: room.players[i].pid == room.hostPid)
                : _EmptySlot(first: i == room.players.length && i < perRow * 2),
          ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({super.key, required this.p, required this.host});
  final PlayerView p;
  final bool host;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          PbAvatar(size: 156, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !p.connected),
          if (host)
            Positioned(
              top: -26,
              left: 0,
              right: 0,
              child: Center(child: Text('👑', style: TextStyle(fontSize: 48, height: 1))),
            ),
          if (!p.connected)
            const Positioned(
              right: 0,
              bottom: 4,
              child: Text('📵', style: TextStyle(fontSize: 40)),
            ),
        ]),
        const SizedBox(height: 14),
        Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Pb.t(34, weight: 600, color: p.connected ? Pb.text : Pb.muted),
        ),
        if (p.score > 0) Text('${Pb.pts(p.score)} pts', style: Pb.t(26, weight: 600, color: Pb.yellow)),
      ]),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.first});
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 156,
        height: 156,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Pb.card.withValues(alpha: first ? .7 : .35),
          border: Border.all(color: Pb.cardHi.withValues(alpha: first ? 1 : .5), width: 4),
        ),
        alignment: Alignment.center,
        child: Text(first ? '?' : '', style: Pb.t(70, weight: 600, color: Pb.muted)),
      ),
      const SizedBox(height: 14),
      Text(first ? 'En attente…' : '', style: Pb.t(30, color: Pb.muted)),
    ]);
  }
}

class _GamesStrip extends StatelessWidget {
  const _GamesStrip({required this.room});
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    final host = room.host;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        host == null
            ? 'Le premier joueur arrivé choisira le jeu'
            : '${host.name} choisit le jeu sur son téléphone',
        style: Pb.t(28, color: Pb.muted),
      ),
      const SizedBox(height: 14),
      Row(children: [
        for (final g in room.games) ...[
          Expanded(child: _GameCard(g: g, selected: g.id == room.selectedGame)),
          if (g != room.games.last) const SizedBox(width: 20),
        ],
      ]),
    ]);
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.g, required this.selected});
  final GameInfo g;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: selected ? Pb.cardHi : Pb.card.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: selected ? Pb.pink : Colors.transparent, width: 4),
        boxShadow: selected ? [BoxShadow(color: Pb.pink.withValues(alpha: .35), blurRadius: 30)] : null,
      ),
      child: Row(children: [
        Text(g.emoji, style: const TextStyle(fontSize: 46)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(25, weight: 600, height: 1.1)),
            Text(g.ready ? '${g.min}+ joueurs' : 'Bientôt',
                style: Pb.t(21, color: g.ready ? Pb.muted : Pb.yellow)),
          ]),
        ),
      ]),
    );
  }
}

class _NetBadge extends StatelessWidget {
  const _NetBadge({required this.state});
  final ValueNotifier<NetState> state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: state,
      builder: (_, s, _) {
        if (s == NetState.online) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: Pb.red.withValues(alpha: .9), borderRadius: BorderRadius.circular(30)),
          child: Text('Connexion au serveur…', style: Pb.t(28, weight: 600)),
        );
      },
    );
  }
}

/// Bouton son de la TV (accessible à la télécommande)
class _MusicButton extends StatefulWidget {
  const _MusicButton();

  @override
  State<_MusicButton> createState() => _MusicButtonState();
}

class _MusicButtonState extends State<_MusicButton> {
  @override
  Widget build(BuildContext context) {
    final muted = Music.instance.muted;
    return TextButton.icon(
      onPressed: () async {
        await Music.instance.toggle();
        if (mounted) setState(() {});
      },
      icon: Icon(muted ? Icons.music_off_rounded : Icons.music_note_rounded, size: 30, color: Pb.muted),
      label: Text(muted ? 'Musique coupée' : 'Musique', style: Pb.t(26, color: Pb.muted)),
    );
  }
}
