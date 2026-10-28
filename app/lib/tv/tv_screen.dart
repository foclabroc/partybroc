import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'update/update.dart';

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
  late final AppLifecycleListener _life;
  bool _dialog = false;
  TvUpdate? _update; // nouvelle version de l'appli TV disponible
  Timer? _updateTimer;
  DateTime _lastCheck = DateTime(2000);

  @override
  void initState() {
    super.initState();
    // Bouton Accueil de la télécommande : la musique s'arrête, elle reprend au retour
    _life = AppLifecycleListener(
      onHide: () => Music.instance.pause(),
      onResume: () {
        Music.instance.resume();
        _sock.kick();
        _checkUpdate();
      },
    );
    // Mise à jour de l'appli TV : au démarrage puis toutes les 6 heures
    Future.delayed(const Duration(seconds: 5), _checkUpdate);
    _updateTimer = Timer.periodic(const Duration(hours: 6), (_) => _checkUpdate(force: true));
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
    _life.dispose();
    _updateTimer?.cancel();
    _sub?.cancel();
    _sock.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------- mise à jour de l'appli TV
  Future<void> _checkUpdate({bool force = false}) async {
    if (kIsWeb) return;
    if (!force && DateTime.now().difference(_lastCheck) < const Duration(minutes: 10)) return;
    _lastCheck = DateTime.now();
    final u = await checkTvUpdate();
    if (!mounted || u == null) return;
    final isNew = _update?.versionCode != u.versionCode;
    setState(() => _update = u);
    // On le propose tout de suite, mais jamais pendant une partie
    if (isNew && _room?.live == null) _offerUpdate();
  }

  Future<void> _offerUpdate() async {
    final u = _update;
    if (u == null || _dialog || !mounted) return;
    _dialog = true;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _UpdateDialog(update: u));
    _dialog = false;
  }

  // Touche Retour de la télécommande
  Future<void> _onBack() async {
    if (_dialog) return;
    final inGame = _room?.live != null;
    _dialog = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _TvDialog(
        title: inGame ? 'Arrêter la partie ?' : 'Quitter PartyBroc TV ?',
        text: inGame ? 'On revient au salon. Les points déjà gagnés sont gardés.' : 'Le salon reste ouvert 15 minutes si tu reviens.',
        yes: inGame ? 'Arrêter la partie' : 'Quitter',
      ),
    );
    _dialog = false;
    if (ok != true) return;
    if (inGame) {
      _sock.send({'t': 'tv_game_msg', 'm': {'t': 'tv_stop'}});
    } else {
      await Music.instance.pause();
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Appli TV : la touche Retour ouvre un menu au lieu de ne rien faire
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !kIsWeb) _onBack();
      },
      // Télécommande : flèches = changer de bouton, OK = appuyer (aussi dans un navigateur)
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
          SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
          SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
          SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        child: _content(),
      ),
    );
  }

  Widget _content() {
    // Dans un navigateur, le son ne démarre qu'après un premier appui
    return Listener(
      onPointerDown: (_) => Music.instance.unlock(),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
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
                  _Lobby(room: _room!, onNewRoom: _newRoom, onQuit: _onBack, onUpdate: _update == null ? null : _offerUpdate),
                Positioned(top: 30, left: 0, right: 0, child: Center(child: _NetBadge(state: _sock.state))),
                if (!kIsWeb && _room?.live != null)
                  Positioned(
                    right: 36,
                    bottom: 20,
                    child: Text('⮌  Retour : arrêter la partie', style: Pb.t(24, color: Pb.muted.withValues(alpha: .7))),
                  ),
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
  const _Lobby({required this.room, required this.onNewRoom, required this.onQuit, this.onUpdate});
  final RoomView room;
  final VoidCallback onNewRoom;
  final VoidCallback onQuit;
  final VoidCallback? onUpdate;

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
          // Boutons pilotables à la télécommande (flèches + OK), le focus est bien visible
          if (onUpdate != null) ...[
            TvButton(icon: Icons.system_update_rounded, label: 'Mise à jour', onPressed: onUpdate!, highlight: true, autofocus: true),
            const SizedBox(width: 16),
          ],
          _MusicButton(autofocus: onUpdate == null),
          const SizedBox(width: 16),
          TvButton(icon: Icons.refresh_rounded, label: 'Nouveau salon', onPressed: onNewRoom),
          if (!kIsWeb) ...[
            const SizedBox(width: 16),
            TvButton(icon: Icons.power_settings_new_rounded, label: 'Quitter', onPressed: onQuit),
          ],
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
  const _MusicButton({this.autofocus = false});
  final bool autofocus;

  @override
  State<_MusicButton> createState() => _MusicButtonState();
}

class _MusicButtonState extends State<_MusicButton> {
  @override
  Widget build(BuildContext context) {
    final muted = Music.instance.muted;
    return TvButton(
      autofocus: widget.autofocus,
      icon: muted ? Icons.music_off_rounded : Icons.music_note_rounded,
      label: muted ? 'Musique coupée' : 'Musique',
      onPressed: () async {
        await Music.instance.toggle();
        if (mounted) setState(() {});
      },
    );
  }
}

/// Boîte de dialogue lisible de loin, pilotable à la télécommande
class _TvDialog extends StatelessWidget {
  const _TvDialog({required this.title, required this.text, required this.yes});
  final String title, text, yes;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Pb.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: Pb.t(28, weight: 700)),
      content: Text(text, style: Pb.t(20, color: Pb.muted)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        // « Annuler » a le focus : un appui sur OK par erreur ne quitte pas
        OutlinedButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(yes),
        ),
      ],
    );
  }
}

/// Proposer, télécharger et lancer l'installation de la nouvelle version
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});
  final TvUpdate update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> with WidgetsBindingObserver {
  double? _progress; // null = pas encore lancé
  String? _error;
  bool _needPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour des réglages « Sources inconnues » : on relance tout seul
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needPermission) _go();
  }

  Future<void> _go() async {
    setState(() {
      _progress = 0;
      _error = null;
      _needPermission = false;
    });
    try {
      await installTvUpdate(widget.update, (p) {
        if (mounted) setState(() => _progress = p);
      });
      // L'installateur Android est ouvert : il remplace l'appli puis la relance
      if (mounted) Navigator.pop(context);
    } on NeedInstallPermission {
      if (mounted) setState(() { _progress = null; _needPermission = true; });
    } catch (e) {
      if (mounted) setState(() { _progress = null; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final busy = _progress != null;
    return AlertDialog(
      backgroundColor: Pb.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Nouvelle version ${u.versionName} 🎉', style: Pb.t(28, weight: 700)),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (u.notes.isNotEmpty) Text(u.notes, style: Pb.t(19, color: Pb.muted)),
          if (_needPermission) ...[
            const SizedBox(height: 12),
            Text('Une seule fois : autorise « PartyBroc TV » à installer des applications '
                '(réglage « Sources inconnues »), puis reviens ici avec la touche Retour.',
                style: Pb.t(19, color: Pb.yellow)),
          ],
          if (busy) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 10, color: Pb.pink, backgroundColor: Pb.card),
            const SizedBox(height: 8),
            Text('Téléchargement… ${((_progress ?? 0) * 100).round()} %', style: Pb.t(18, color: Pb.muted)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: Pb.t(18, color: Pb.red)),
          ],
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: busy
          ? const []
          : [
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
              if (_needPermission)
                FilledButton(autofocus: true, onPressed: openInstallSettings, child: const Text('Ouvrir les réglages'))
              else
                FilledButton(autofocus: true, onPressed: _go, child: Text(_error == null ? 'Mettre à jour' : 'Réessayer')),
            ],
    );
  }
}

/// Bouton de l'écran TV : se sélectionne aux flèches de la télécommande, s'active avec OK,
/// et le bouton sélectionné est bien visible (cadre rose, un peu plus gros)
class TvButton extends StatefulWidget {
  const TvButton({super.key, required this.icon, required this.label, required this.onPressed, this.highlight = false, this.autofocus = false});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool highlight;
  final bool autofocus;

  @override
  State<TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<TvButton> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.highlight ? Pb.pink : (_focus ? Pb.cardHi : Pb.card.withValues(alpha: .6));
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: _focus ? 1.08 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(40),
          onFocusChange: (f) => setState(() => _focus = f),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: _focus ? Colors.white : Colors.transparent, width: 4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, size: 30, color: widget.highlight || _focus ? Colors.white : Pb.muted),
              const SizedBox(width: 10),
              Text(widget.label, style: Pb.t(26, weight: 600, color: widget.highlight || _focus ? Colors.white : Pb.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
