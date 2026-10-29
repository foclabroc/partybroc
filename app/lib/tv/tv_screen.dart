import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/common_ui.dart';
import '../games/draw_board.dart';
import '../games/tv_game.dart';
import '../live_feed.dart';
import '../models.dart';
import '../music.dart';
import '../sfx.dart';
import '../voice.dart';
import '../games/party_ui.dart';
import '../net.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'tv_keys.dart';
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
  final _sfx = SfxDirector(); // bruitages d'après l'état du salon
  final _voice = VoiceDirector(); // animateur vocal
  final _stats = ValueNotifier<Map<String, dynamic>?>(null); // statistiques du salon permanent
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
    Sfx.instance.init();
    Voice.instance.init();
    Music.instance.init().then((_) {
      if (mounted) setState(() {});
      Music.instance.play('salon');
    });
  }

  // Salon permanent retenu par cet écran (avec sa clé, plus besoin du mot de passe)
  String? get _permCode => _prefs?.getString('tv_perm_code');

  void _hello(PbSocket s) {
    final perm = _permCode;
    if (perm != null) {
      s.send({'t': 'perm_open', 'code': perm, 'key': _prefs?.getString('tv_perm_key')});
      return;
    }
    s.send({
      't': 'tv_hello',
      'code': _prefs?.getString('tv_code'),
      'tvToken': _prefs?.getString('tv_token'),
    });
  }

  void _forgetPerm() {
    _prefs?.remove('tv_perm_code');
    _prefs?.remove('tv_perm_key');
  }

  // Créer ou ouvrir un salon permanent (nom + mot de passe)
  Future<void> _permDialog() async {
    if (_dialog) return;
    _dialog = true;
    final r = await showDialog<_PermRequest>(context: context, builder: (_) => const TvKeys(child: _PermDialog()));
    _dialog = false;
    if (r == null) return;
    setState(() => _error = null);
    _sock.send({'t': r.create ? 'perm_create' : 'perm_open', 'code': r.code, 'password': r.password});
  }

  // Statistiques du salon permanent (classement de tous les temps, champions)
  Future<void> _statsDialog() async {
    if (_dialog) return;
    _dialog = true;
    _stats.value = null;
    _sock.send({'t': 'perm_stats'});
    await showDialog<void>(
      context: context,
      builder: (ctx) => TvKeys(
        child: AlertDialog(
          backgroundColor: Pb.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: SizedBox(
            width: 900,
            child: SingleChildScrollView(
              child: ValueListenableBuilder(
                valueListenable: _stats,
                builder: (_, st, _) => st == null
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Pb.pink)))
                    : PermStatsView(stats: st, games: _room?.games ?? const [], scale: 1.2, wide: true),
              ),
            ),
          ),
          actions: [FilledButton(autofocus: true, onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
        ),
      ),
    );
    _dialog = false;
  }

  // Quitter le salon permanent : retour à un salon normal (le permanent reste ouvert)
  void _leavePerm() {
    _forgetPerm();
    _newRoom();
  }

  void _onMessage(Map<String, dynamic> m) {
    if (LiveFeed.instance.handle(m)) return;
    switch (m['t']) {
      case 'perm_stats':
        _stats.value = m;
      case 'tv_ok':
        if (m['perm'] == true) {
          _prefs?.setString('tv_perm_code', m['code'] as String);
          if (m['key'] is String) _prefs?.setString('tv_perm_key', m['key'] as String);
        } else {
          _forgetPerm();
          _prefs?.setString('tv_code', m['code'] as String);
          _prefs?.setString('tv_token', m['tvToken'] as String);
        }
        setState(() => _error = null);
      case 'room':
        // Classement demandé par l'hôte : dans un salon permanent, on charge aussi celui de tous les temps
        final board = (m['room'] as Map)['board'] == true;
        if (board && _room?.board != true && (m['room'] as Map)['perm'] == true) {
          _stats.value = null;
          _sock.send({'t': 'perm_stats'});
        }
        setState(() {
          _room = RoomView.fromJson(m['room'] as Map<String, dynamic>);
          _error = null;
        });
        _sfx.onRoom(m['room'] as Map<String, dynamic>);
        _voice.onRoom(m['room'] as Map<String, dynamic>);
        // Musique : « jeu » pendant une partie, « salon » au salon et au podium
        final live = _room!.live;
        Music.instance.play(live != null && live['phase'] != 'podium' ? 'jeu' : 'salon');
      case 'closed':
        // Salon fermé côté serveur : on en ouvre un neuf (ou on rouvre le permanent)
        _prefs?.remove('tv_code');
        _prefs?.remove('tv_token');
        setState(() => _room = null);
        _hello(_sock);
      case 'draw':
        DrawBoard.instance.apply(m);
      case 'replaced':
        setState(() => _error = 'Ce salon est maintenant affiché sur un autre écran.');
      case 'error':
        // Salon permanent supprimé, ou clé de l'écran plus valable : retour à un salon normal
        if (_room == null && _permCode != null && (m['code'] == 'no_room' || m['code'] == 'need_pass')) {
          _forgetPerm();
          _hello(_sock);
        }
        setState(() => _error = m['msg'] as String?);
    }
  }


  void _newRoom() {
    _prefs?.remove('tv_code');
    _prefs?.remove('tv_token');
    _sock.send({'t': 'tv_new'});
  }

  @override
  void dispose() {
    _life.dispose();
    _sfx.dispose();
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
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => TvKeys(child: _UpdateDialog(update: u)));
    _dialog = false;
  }

  // Touche Retour de la télécommande
  Future<void> _onBack() async {
    if (_dialog) return;
    final inGame = _room?.live != null;
    _dialog = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => TvKeys(child: _TvDialog(
        title: inGame ? 'Arrêter la partie ?' : 'Quitter PartyBroc TV ?',
        text: inGame ? 'On revient au salon. Les points déjà gagnés sont gardés.' : 'Le salon reste ouvert 15 minutes si tu reviens.',
        yes: inGame ? 'Arrêter la partie' : 'Quitter',
      )),
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
      child: TvKeys(
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
                  tvGameView(_room!)
                else if (_room!.soiree != null && _room!.soiree!.step != 'game')
                  TvSoiree(room: _room!)
                else if (_room!.board)
                  TvBoard(room: _room!, stats: _stats)
                else
                  _Lobby(
                    room: _room!,
                    onNewRoom: _room!.perm ? _leavePerm : _newRoom,
                    onPerm: _permDialog,
                    onStats: _statsDialog,
                    onQuit: _onBack,
                    onUpdate: _update == null ? null : _offerUpdate,
                  ),
                // Réactions et messages des joueurs, par-dessus tout
                if (_room != null) const Positioned.fill(child: LiveLayer()),
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
  const _Lobby({required this.room, required this.onNewRoom, required this.onPerm, required this.onStats, required this.onQuit, this.onUpdate});
  final RoomView room;
  final VoidCallback onNewRoom;
  final VoidCallback onPerm;
  final VoidCallback onStats;
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
          const SizedBox(width: 30),
          // Boutons pilotables à la télécommande (flèches + OK), le focus est bien visible.
          // Rétrécis si besoin (Mise à jour + Quitter en plus sur l'appli TV).
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (onUpdate != null) ...[
            TvButton(icon: Icons.system_update_rounded, label: 'Mise à jour', onPressed: onUpdate!, highlight: true, autofocus: true),
            const SizedBox(width: 16),
          ],
          _SoundButton(autofocus: onUpdate == null),
          const SizedBox(width: 16),
          TvButton(icon: Icons.lock_rounded, label: 'Salon permanent', onPressed: onPerm),
          if (room.perm) ...[
            const SizedBox(width: 16),
            TvButton(icon: Icons.emoji_events_rounded, label: 'Statistiques', onPressed: onStats),
          ],
          const SizedBox(width: 16),
          TvButton(icon: Icons.refresh_rounded, label: room.perm ? 'Salon normal' : 'Nouveau salon', onPressed: onNewRoom),
          if (!kIsWeb) ...[
            const SizedBox(width: 16),
            TvButton(icon: Icons.power_settings_new_rounded, label: 'Quitter', onPressed: onQuit),
          ],
                ]),
              ),
            ),
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
                // Tout le contenu rétrécit s'il manque de place (salon permanent + 2 rangées de jeux),
                // sinon « + le mot de passe du salon » débordait sur la ligne des jeux
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 468,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                  Text(room.perm ? 'salon permanent 🔒' : 'avec le code', style: Pb.t(26, color: Pb.muted)),
                  const SizedBox(height: 18),
                  _CodeLetters(code: room.code),
                  if (room.perm) ...[
                    const SizedBox(height: 14),
                    Text('+ le mot de passe du salon', style: Pb.t(24, color: Pb.muted)),
                  ],
                ]),
                  ),
                ),
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
                SizedBox(height: room.teams != null ? 14 : 34),
                if (room.teams != null) ...[TvTeamsBar(teams: room.teams!, size: 28), const SizedBox(height: 14)],
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
    // Nom de salon permanent (jusqu'à 12 lettres) : les cases rétrécissent
    final long = code.length > 4;
    return FittedBox(
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (final ch in code.split(''))
        Container(
          width: long ? 64 : 84,
          height: 96,
          margin: EdgeInsets.symmetric(horizontal: long ? 4 : 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Pb.yellow,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Pb.yellow.withValues(alpha: .4), blurRadius: 24)],
          ),
          child: Text(ch, style: Pb.t(long ? 54 : 64, weight: 700, color: Pb.bg, height: 1)),
        ),
      ]),
    );
  }
}

class _PlayersGrid extends StatelessWidget {
  const _PlayersGrid({required this.room});
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    // Jusqu'à 15 places : 3 rangées de 5, plus petites
    final slots = room.maxPlayers;
    final small = slots > 10;
    return Wrap(
      spacing: small ? 22 : 26,
      runSpacing: small ? 12 : 34,
      children: [
        for (var i = 0; i < slots; i++)
          SizedBox(
            width: small ? 170 : 196,
            child: i < room.players.length
                ? _PlayerTile(key: ValueKey(room.players[i].pid), p: room.players[i], host: room.players[i].pid == room.hostPid, small: small)
                : _EmptySlot(first: i == room.players.length, small: small),
          ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({super.key, required this.p, required this.host, this.small = false});
  final PlayerView p;
  final bool host, small;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          PbAvatar(size: small ? 112 : 156, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !p.connected),
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
        SizedBox(height: small ? 6 : 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // pastille de son équipe
          if (p.team != null)
            Container(width: 16, height: 16, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: TeamsView.color(p.team!), shape: BoxShape.circle)),
          Flexible(
            child: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Pb.t(small ? 28 : 34, weight: 600, color: p.connected ? Pb.text : Pb.muted),
            ),
          ),
        ]),
        if (p.score > 0) Text('${Pb.pts(p.score)} pts', style: Pb.t(small ? 22 : 26, weight: 600, color: Pb.yellow, height: 1.1)),
      ]),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.first, this.small = false});
  final bool first, small;

  @override
  Widget build(BuildContext context) {
    final s = small ? 112.0 : 156.0;
    return Column(children: [
      Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Pb.card.withValues(alpha: first ? .7 : .35),
          border: Border.all(color: Pb.cardHi.withValues(alpha: first ? 1 : .5), width: 4),
        ),
        alignment: Alignment.center,
        child: Text(first ? '?' : '', style: Pb.t(small ? 52 : 70, weight: 600, color: Pb.muted)),
      ),
      SizedBox(height: small ? 6 : 14),
      Text(first ? 'En attente…' : '', style: Pb.t(small ? 24 : 30, color: Pb.muted)),
    ]);
  }
}

class _GamesStrip extends StatelessWidget {
  const _GamesStrip({required this.room});
  final RoomView room;

  int get _perRow => room.games.length > 12 ? 7 : 6;

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
      // Les jeux sur deux rangées (6 ou 7 par rangée)
      for (var row = 0; row * _perRow < room.games.length; row++) ...[
        if (row > 0) const SizedBox(height: 12),
        Row(children: [
          for (var i = row * _perRow; i < row * _perRow + _perRow; i++) ...[
            if (i > row * _perRow) const SizedBox(width: 14),
            Expanded(
              child: i < room.games.length
                  ? _GameCard(g: room.games[i], selected: room.games[i].id == room.selectedGame, compact: _perRow > 6)
                  : const SizedBox.shrink(),
            ),
          ],
        ]),
      ],
    ]);
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.g, required this.selected, this.compact = false});
  final GameInfo g;
  final bool selected;
  final bool compact; // 7 par rangée : titre sur 2 lignes, sans le nombre de joueurs

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 86,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
      decoration: BoxDecoration(
        color: selected ? Pb.cardHi : Pb.card.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: selected ? Pb.pink : Colors.transparent, width: 4),
        boxShadow: selected ? [BoxShadow(color: Pb.pink.withValues(alpha: .35), blurRadius: 30)] : null,
      ),
      child: Row(children: [
        Text(g.emoji, style: TextStyle(fontSize: compact ? 32 : 38)),
        SizedBox(width: compact ? 8 : 12),
        Expanded(
          child: compact
              ? Text(g.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Pb.t(22, weight: 600, height: 1.05))
              : Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(23, weight: 600, height: 1.1)),
                  Text(g.ready ? '${g.min}+ joueurs' : 'Bientôt', style: Pb.t(19, color: g.ready ? Pb.muted : Pb.yellow)),
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

/// Bouton « Sons » : musique, bruitages et animateur vocal, chacun réglable
class _SoundButton extends StatelessWidget {
  const _SoundButton({this.autofocus = false});
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final all = Music.instance.muted && Sfx.instance.muted && Voice.instance.muted;
    return TvButton(
      autofocus: autofocus,
      icon: all ? Icons.volume_off_rounded : Icons.volume_up_rounded,
      label: 'Sons',
      onPressed: () => showDialog<void>(context: context, builder: (_) => const TvKeys(child: _SoundDialog())),
    );
  }
}

class _SoundDialog extends StatefulWidget {
  const _SoundDialog();

  @override
  State<_SoundDialog> createState() => _SoundDialogState();
}

class _SoundDialogState extends State<_SoundDialog> {
  Widget _row(String label, IconData on, bool muted, Future<void> Function() toggle, {bool autofocus = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TvButton(
          autofocus: autofocus,
          icon: muted ? Icons.toggle_off_rounded : on,
          label: '$label : ${muted ? 'coupé' : 'activé'}',
          highlight: !muted,
          onPressed: () async {
            await toggle();
            if (mounted) setState(() {});
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Pb.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Sons 🔊', style: Pb.t(28, weight: 700)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row('Musique', Icons.music_note_rounded, Music.instance.muted, Music.instance.toggle, autofocus: true),
        _row('Bruitages', Icons.campaign_rounded, Sfx.instance.muted, Sfx.instance.toggle),
        _row('Animateur vocal', Icons.record_voice_over_rounded, Voice.instance.muted, Voice.instance.toggle),
      ]),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [OutlinedButton(style: _actionSize, onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}

// Boutons d'une boîte de dialogue : largeur du texte (le thème les met sur toute la largeur)
final _actionSize = OutlinedButton.styleFrom(minimumSize: const Size(0, 52));

class _PermRequest {
  const _PermRequest(this.create, this.code, this.password);
  final bool create;
  final String code, password;
}

/// Salon permanent : ouvrir un salon existant, ou en créer un (nom + mot de passe).
/// Le clavier de la TV s'ouvre avec OK sur un champ.
class _PermDialog extends StatefulWidget {
  const _PermDialog();

  @override
  State<_PermDialog> createState() => _PermDialogState();
}

class _PermDialogState extends State<_PermDialog> {
  bool _create = false;
  final _code = TextEditingController();
  final _pw = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _code.dispose();
    _pw.dispose();
    super.dispose();
  }

  static String _clean(String s) => s.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');

  void _ok() {
    final code = _clean(_code.text);
    if (code.length < 5 || code.length > 12) return setState(() => _err = 'Le nom : 5 à 12 lettres (ex. FAMILLE)');
    if (_pw.text.length < 4) return setState(() => _err = 'Mot de passe : 4 caractères minimum');
    Navigator.pop(context, _PermRequest(_create, code, _pw.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Pb.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Salon permanent 🔒', style: Pb.t(28, weight: 700)),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Toujours ouvert, protégé par un mot de passe, et il se souvient des joueurs et de leur score. '
            'La famille à distance l’ouvre aussi sur son PC ou sa TV (même adresse, /tv).',
            style: Pb.t(18, color: Pb.muted),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _tab('Ouvrir', !_create, () => setState(() => _create = false), autofocus: true)),
            const SizedBox(width: 10),
            Expanded(child: _tab('Créer', _create, () => setState(() => _create = true))),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            maxLength: 12,
            style: Pb.t(24, weight: 600, color: Pb.yellow),
            decoration: const InputDecoration(labelText: 'Nom du salon', hintText: 'FAMILLE', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _ok(),
            style: Pb.t(24),
            decoration: const InputDecoration(labelText: 'Mot de passe'),
          ),
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: Pb.t(18, color: Pb.red)),
          ],
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        OutlinedButton(style: _actionSize, onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: _ok,
          child: Text(_create ? 'Créer le salon' : 'Ouvrir'),
        ),
      ],
    );
  }

  Widget _tab(String label, bool on, VoidCallback tap, {bool autofocus = false}) => OutlinedButton(
        autofocus: autofocus,
        style: OutlinedButton.styleFrom(
          backgroundColor: on ? Pb.pink : null,
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: tap,
        child: Text(label),
      );
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
        OutlinedButton(style: _actionSize, autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
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
              OutlinedButton(style: _actionSize, onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
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

/// Classement affiché sur la TV à la demande de l'hôte : celui de la soirée (salon
/// normal), ou celui de tous les temps avec les champions par jeu (salon permanent,
/// où le score d'un joueur est déjà son total depuis la création du salon).
class TvBoard extends StatelessWidget {
  const TvBoard({super.key, required this.room, required this.stats});
  final RoomView room;
  final ValueNotifier<Map<String, dynamic>?> stats;

  @override
  Widget build(BuildContext context) {
    final teams = room.teams;
    final Widget body;
    if (room.perm) {
      body = ValueListenableBuilder(
        valueListenable: stats,
        builder: (_, st, _) => st == null
            ? const Center(child: CircularProgressIndicator(color: Pb.pink))
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(width: 1700, child: PermStatsView(stats: st, games: room.games, scale: 1.6, wide: true)),
              ),
      );
    } else {
      final players = [...room.players]..sort((a, b) => b.score - a.score);
      body = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 1200,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (players.isEmpty) Text('Personne pour l’instant', style: Pb.t(36, color: Pb.muted)),
            for (var i = 0; i < players.length && i < 15; i++) _row(players, i),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(90, 100, 90, 50),
      child: Column(children: [
        Text(room.perm ? '🏆 Classement de tous les temps' : '🏆 Classement de la soirée', style: Pb.t(64, weight: 700)),
        const SizedBox(height: 20),
        if (teams != null) ...[
          Wrap(spacing: 18, runSpacing: 12, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < teams.count; i++)
              TvChip(
                text: '${teams.names[i]} · ${Pb.pts(teams.scores[i])}',
                color: Colors.white,
                bg: TeamsView.colors[i % TeamsView.colors.length].withValues(alpha: .55),
                size: 32,
              ),
          ]),
          const SizedBox(height: 24),
        ],
        Expanded(child: body),
      ]),
    );
  }

  Widget _row(List<PlayerView> players, int i) {
    final p = players[i];
    // ex aequo : même rang
    var rank = i + 1;
    while (rank > 1 && players[rank - 2].score == p.score) {
      rank--;
    }
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '$rank' };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        SizedBox(width: 80, child: Text(medal, style: Pb.t(44, weight: 700))),
        PbAvatar(size: 64, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !p.connected),
        const SizedBox(width: 18),
        Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(40, weight: 600))),
        Text('${Pb.pts(p.score)} pts', style: Pb.t(40, weight: 700, color: rank == 1 ? Pb.yellow : Pb.text)),
      ]),
    );
  }
}
