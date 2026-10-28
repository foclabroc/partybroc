import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/calcul_ui.dart';
import '../games/dessin_ui.dart';
import '../games/justeprix_ui.dart';
import '../games/memoire_ui.dart';
import '../games/petitbac_ui.dart';
import '../games/quiadit_ui.dart';
import '../games/survie_ui.dart';
import '../games/zoom_ui.dart';
import '../games/draw_board.dart';
import '../games/droles_ui.dart';
import '../games/quidenous_ui.dart';
import '../games/quiz_play.dart';
import '../games/reflexes_ui.dart';
import '../games/quiz_state.dart';
import '../games/tv_game.dart';
import '../live_feed.dart';
import '../models.dart';
import '../sfx.dart';
import '../voice.dart';
import '../games/party_ui.dart';
import '../net.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'home_icon/home_icon.dart';
import 'profile.dart';

enum _Step { loading, form, joining, lobby }

/// Écran du téléphone : on rejoint avec le code, son pseudo et sa photo,
/// puis on attend dans le salon (l'hôte choisit et lance le jeu).
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final PbSocket _sock;
  StreamSubscription? _sub;
  late final AppLifecycleListener _life;
  SharedPreferences? _prefs;

  _Step _step = _Step.loading;
  Profile _profile = Profile();
  late final _code = TextEditingController(text: (widget.initialCode ?? '').toUpperCase());
  final _pw = TextEditingController();
  bool _showScreen = true; // salon permanent : l'écran du jeu aussi sur le téléphone
  bool _phoneSfx = true; // salon permanent : les bruitages de la TV aussi sur le téléphone
  final _sfx = SfxDirector();
  final _voice = VoiceDirector();
  final _stats = ValueNotifier<Map<String, dynamic>?>(null);
  String? _formError;

  // Session en cours (pour revenir après une coupure)
  String? _sCode;
  String? _sToken;
  String? _myPid;
  RoomView? _room;
  Map<String, dynamic>? _you; // état perso dans la partie en cours
  bool _pendingJoin = false;

  @override
  void initState() {
    super.initState();
    _sock = PbSocket(onOpen: _onOpen);
    _sub = _sock.messages.listen(_onMessage);
    DrawBoard.instance.requestSync = () => _sock.send({'t': 'game_msg', 'm': {'t': 'drw_sync'}});
    _life = AppLifecycleListener(onResume: _sock.kick);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _profile = await Profile.load(prefs);
    _showScreen = prefs.getBool('show_screen') ?? true;
    _phoneSfx = prefs.getBool('phone_sfx') ?? true;
    _sCode = prefs.getString('s_code');
    _sToken = prefs.getString('s_token');
    final wanted = widget.initialCode?.toUpperCase();
    // On a déjà une place dans ce salon (ou pas de code imposé) : on tente d'y revenir
    final canResume = _sCode != null && _sToken != null && (wanted == null || wanted.isEmpty || wanted == _sCode);
    if (!canResume) _clearSession();
    if (_code.text.isEmpty && _sCode != null) _code.text = _sCode!;
    setState(() => _step = canResume ? _Step.joining : _Step.form);
    _sock.connect();
  }

  void _onOpen(PbSocket s) {
    if (_sCode != null && _sToken != null) {
      s.send({'t': 'resume', 'code': _sCode, 'token': _sToken});
    } else if (_pendingJoin) {
      s.send(_joinMsg(_cleanCode(_code.text)));
    }
  }

  static String _cleanCode(String s) => s.trim().toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  static bool _isPerm(String code) => code.length >= 5;

  // Jeton de membre d'un salon permanent : plus besoin du mot de passe la fois suivante
  String? _mtoken(String code) => _prefs?.getString('m_$code');

  Map<String, dynamic> _joinMsg(String code) => {
        't': 'join',
        'code': code,
        if (_isPerm(code)) ...{
          'password': _pw.text,
          if (_mtoken(code) != null) 'mtoken': _mtoken(code),
        },
        ..._profile.toMessage(),
      };

  void _clearSession() {
    _sCode = null;
    _sToken = null;
    _myPid = null;
    _prefs?.remove('s_code');
    _prefs?.remove('s_token');
  }

  void _backToForm(String? msg) {
    _clearSession();
    LiveFeed.instance.reset();
    setState(() {
      _room = null;
      _pendingJoin = false;
      _step = _Step.form;
      _formError = msg;
    });
  }

  void _onMessage(Map<String, dynamic> m) {
    if (LiveFeed.instance.handle(m)) return;
    switch (m['t']) {
      case 'perm_stats':
        _stats.value = m;
      case 'joined':
        _sCode = m['code'] as String;
        _sToken = m['token'] as String;
        _myPid = m['pid'] as String;
        _prefs?.setString('s_code', _sCode!);
        _prefs?.setString('s_token', _sToken!);
        if (m['mtoken'] is String) _prefs?.setString('m_${_sCode!}', m['mtoken'] as String);
        _pw.clear();
        _pendingJoin = false;
        HapticFeedback.mediumImpact();
        setState(() => _step = _Step.lobby);
      case 'room':
        setState(() {
          _room = RoomView.fromJson(m['room'] as Map<String, dynamic>);
          _you = m['you'] as Map<String, dynamic>?;
        });
        // Joueur à distance (salon permanent) : les mêmes bruitages que la TV, s'il le veut
        if (_room!.perm && _phoneSfx) {
          Sfx.instance.init();
          Voice.instance.init();
          _sfx.onRoom(m['room'] as Map<String, dynamic>);
          _voice.onRoom(m['room'] as Map<String, dynamic>);
        }
      case 'draw':
        DrawBoard.instance.apply(m);
      case 'dsn_close':
        _toast('🔥 Chaud ! « ${m['text']} » est presque bon');
      case 'profile_ok':
        _toast('Profil mis à jour');
      case 'kicked':
        _backToForm("L'hôte t'a retiré du salon.");
      case 'closed':
        _backToForm('Le salon a été fermé.');
      case 'left':
        _backToForm(null);
      case 'replaced':
        _backToForm('Tu as rejoint le salon depuis un autre onglet.');
      case 'error':
        final code = m['code'] as String?;
        final msg = m['msg'] as String? ?? 'Erreur';
        // Salon permanent : la place a expiré (serveur redémarré…) mais le téléphone est
        // membre : on rentre tout seul, sans redemander le mot de passe
        final was = _sCode;
        if (code == 'expired' && was != null && _isPerm(was) && _mtoken(was) != null && _prefs != null) {
          _clearSession();
          _code.text = was;
          _pendingJoin = true;
          setState(() => _step = _Step.joining);
          _sock.send(_joinMsg(was));
          return;
        }
        if (code == 'need_pass' && _isPerm(_cleanCode(_code.text))) _prefs?.remove('m_${_cleanCode(_code.text)}');
        if (_step == _Step.lobby && code != 'expired' && code != 'no_room') {
          _toast(msg);
        } else {
          _backToForm(code == 'expired' ? 'Ta place a expiré, rejoins à nouveau.' : msg);
        }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _join() async {
    final code = _cleanCode(_code.text);
    if (code.length < 4 || code.length > 12) {
      return setState(() => _formError = 'Le code fait 4 lettres (il est affiché sur la TV), ou c’est le nom d’un salon permanent');
    }
    if (_isPerm(code) && _pw.text.isEmpty && _mtoken(code) == null) return setState(() => _formError = 'Mot de passe du salon');
    if (_profile.name.trim().isEmpty) return setState(() => _formError = 'Choisis un pseudo');
    FocusScope.of(context).unfocus();
    await _profile.save(_prefs!);
    _clearSession();
    setState(() {
      _formError = null;
      _step = _Step.joining;
      _pendingJoin = true;
    });
    if (_sock.state.value == NetState.online) {
      _sock.send(_joinMsg(code));
    } else {
      _sock.kick();
    }
  }

  Future<void> _editProfile() async {
    final draft = _profile.copy();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pb.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _ProfileSheet(draft: draft),
    );
    if (ok != true) return;
    _profile = draft;
    await _profile.save(_prefs!);
    _sock.send({'t': 'profile', ..._profile.toMessage()});
    setState(() {});
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pb.bg2,
        title: Text('Quitter le salon ?', style: Pb.t(22, weight: 600)),
        content: Text('Tu pourras revenir avec le code.', style: Pb.t(17, color: Pb.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Rester')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitter')),
        ],
      ),
    );
    if (ok == true) _sock.send({'t': 'leave'});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sfx.dispose();
    _life.dispose();
    _sock.dispose();
    _code.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PartyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(child: _body()),
                    // réactions des autres qui montent, et le dernier message en bulle
                    if (_inRoom) const Positioned.fill(child: LiveLayer(scale: .42, bubbleBottom: 30)),
                    Positioned(top: 8, left: 0, right: 0, child: Center(child: _NetPill(state: _sock.state))),
                  ]),
                ),
                if (_inRoom) PhoneChatBar(send: _sock.send, canChat: !_drawing),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  bool get _inRoom => _step == _Step.lobby && _room != null;

  // Dessin à deviner, pendant qu'on dessine : pas de messages (on soufflerait le mot)
  bool get _drawing => _room?.live?['id'] == 'dessin' && _room?.live?['phase'] == 'draw';

  Widget _body() {
    switch (_step) {
      case _Step.loading:
        return const SizedBox.shrink();
      case _Step.joining:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Pb.pink),
            const SizedBox(height: 18),
            Text('Connexion au salon…', style: Pb.t(20, color: Pb.muted)),
            const SizedBox(height: 30),
            TextButton(onPressed: () => _backToForm(null), child: const Text('Annuler')),
          ]),
        );
      case _Step.form:
        return _form();
      case _Step.lobby:
        final room = _room;
        if (room == null) return const Center(child: CircularProgressIndicator(color: Pb.pink));
        final live = room.live;
        // Soirée enchaînée : entracte (classement) et podium final
        if (live == null && room.soiree != null && room.soiree!.step != 'game') {
          return PhoneSoiree(room: room, myPid: _myPid, isHost: room.hostPid == _myPid, send: _sock.send);
        }
        if (live != null && room.perm) return _withScreen(room, _play(room));
        if (live != null) return _play(room);
        return _LobbyView(
          room: room,
          myPid: _myPid,
          onEdit: _editProfile,
          onLeave: _leave,
          send: _sock.send,
          showScreen: _showScreen,
          onShowScreen: _setShowScreen,
          phoneSfx: _phoneSfx,
          onPhoneSfx: _setPhoneSfx,
          onStats: _openStats,
        );
    }
  }

  // Classement de tous les temps du salon permanent
  void _openStats() {
    _stats.value = null;
    _sock.send({'t': 'perm_stats'});
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pb.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: ValueListenableBuilder(
              valueListenable: _stats,
              builder: (_, st, _) => st == null
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Pb.pink)))
                  : PermStatsView(stats: st, games: _room?.games ?? const []),
            ),
          ),
        ),
      ),
    );
  }

  void _setPhoneSfx(bool v) {
    _prefs?.setBool('phone_sfx', v);
    setState(() => _phoneSfx = v);
    if (v) {
      Sfx.instance.init().then((_) => Sfx.instance.play('pop'));
    }
  }

  void _setShowScreen(bool v) {
    _prefs?.setBool('show_screen', v);
    setState(() => _showScreen = v);
  }

  // Salon permanent (joueurs à distance) : ce que montre la TV, en petit au-dessus des
  // commandes. Un appui le masque ou le réaffiche.
  Widget _withScreen(RoomView room, Widget play) {
    return Column(children: [
      const SizedBox(height: 34),
      if (_showScreen)
        GestureDetector(
          onTap: () => _setShowScreen(false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: PartyBackground(
                  child: FittedBox(child: SizedBox(width: 1920, height: 1080, child: tvGameView(room))),
                ),
              ),
            ),
          ),
        )
      else
        TextButton.icon(
          onPressed: () => _setShowScreen(true),
          icon: const Icon(Icons.tv_rounded, size: 18),
          label: Text('Voir l’écran du jeu', style: Pb.t(15, weight: 600)),
        ),
      Expanded(child: play),
    ]);
  }

  Widget _play(RoomView room) {
    final live = room.live;
    final host = room.hostPid == _myPid;
    switch (live?['id']) {
      case 'quiz':
        return QuizPlay(
          room: room,
          q: QuizState.fromJson(live!),
          you: _you == null ? null : QuizYou.fromJson(_you!),
          isHost: host,
          send: _sock.send,
        );
      case 'quidenous':
        return QdnPlay(room: room, live: live!, you: _you, myPid: _myPid, isHost: host, send: _sock.send);
      case 'droles':
        return DrlPlay(room: room, live: live!, you: _you, isHost: host, send: _sock.send);
      case 'reflexes':
        return RfxPlay(room: room, live: live!, you: _you, isHost: host, send: _sock.send);
      case 'dessin':
        return DsnPlay(room: room, live: live!, you: _you, isHost: host, send: _sock.send);
      case 'justeprix':
        return JpPlay(room: room, live: live!, you: _you, isHost: host, send: _sock.send);
      case 'quiadit':
        return QadPlay(room: room, live: live!, you: _you, myPid: _myPid, isHost: host, send: _sock.send);
      case 'calcul':
        return CalcPlay(room: room, live: live!, you: _you, isHost: host, send: _sock.send);
      case 'memoire':
        return MemPlay(room: room, live: live!, you: _you, isHost: host, send: _sock.send);
      case 'petitbac':
        return BacPlay(room: room, live: live!, you: _you, myPid: _myPid, isHost: host, send: _sock.send);
      case 'zoom':
        return ZoomPlay(room: room, live: live!, you: _you, isHost: host, send: _sock.send);
      case 'survie':
        return SurvPlay(room: room, live: live!, you: _you, isHost: host, send: _sock.send);
    }
    return const SizedBox.shrink();
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
      children: [
        const Center(child: PbLogo(size: 38)),
        const SizedBox(height: 26),
        Text('Code affiché sur la TV (ou nom du salon permanent)', style: Pb.t(16, weight: 600, color: Pb.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          maxLength: 12,
          onChanged: (_) => setState(() {}),
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
            TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
          ],
          style: Pb.t(_code.text.length > 6 ? 30 : 40, weight: 700, color: Pb.yellow)
              .copyWith(letterSpacing: _code.text.length > 6 ? 4 : 14),
          decoration: const InputDecoration(hintText: 'ABCD', counterText: ''),
        ),
        // Salon permanent : mot de passe (sauf si ce téléphone y est déjà venu)
        if (_isPerm(_cleanCode(_code.text))) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _pw,
            obscureText: true,
            style: Pb.t(20),
            decoration: InputDecoration(
              labelText: 'Mot de passe du salon 🔒',
              helperText: _mtoken(_cleanCode(_code.text)) != null ? 'Tu es déjà venu ici : pas besoin du mot de passe' : null,
              helperStyle: Pb.t(14, color: Pb.green),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ProfileEditor(
          profile: _profile,
          onChanged: () {
            setState(() {});
            if (_prefs != null) _profile.save(_prefs!);
          },
        ),
        if (_formError != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Pb.red.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
            child: Text(_formError!, style: Pb.t(16, color: const Color(0xFFFFB3B3))),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: _join, child: const Text("C'est parti !")),
        const SizedBox(height: 12),
        const Center(child: HomeIconButton()),
      ],
    );
  }
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.draft});
  final Profile draft;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Mon profil', textAlign: TextAlign.center, style: Pb.t(24, weight: 700)),
            const SizedBox(height: 18),
            ProfileEditor(profile: widget.draft, onChanged: () => setState(() {})),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: widget.draft.name.trim().isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Enregistrer'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.room,
    required this.myPid,
    required this.onEdit,
    required this.onLeave,
    required this.send,
    required this.showScreen,
    required this.onShowScreen,
    required this.phoneSfx,
    required this.onPhoneSfx,
    required this.onStats,
  });

  final VoidCallback onStats;

  final bool showScreen, phoneSfx;
  final ValueChanged<bool> onShowScreen, onPhoneSfx;
  final RoomView room;
  final String? myPid;
  final VoidCallback onEdit;
  final VoidCallback onLeave;
  final void Function(Map<String, dynamic>) send;

  @override
  Widget build(BuildContext context) {
    final me = room.players.where((p) => p.pid == myPid).firstOrNull;
    final isHost = myPid != null && room.hostPid == myPid;
    final game = room.game;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      children: [
        // ---- Moi ----
        if (me != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Pb.card, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              PbAvatar(size: 64, emoji: me.emoji, color: me.color, photoPath: me.photo),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(me.name, style: Pb.t(22, weight: 700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(isHost ? '👑 Tu es l’hôte' : 'Salon ${room.code}', style: Pb.t(15, color: Pb.muted)),
                ]),
              ),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, color: Pb.muted), tooltip: 'Modifier'),
            ]),
          ),
        if (!room.tvConnected && !room.perm) ...[
          const SizedBox(height: 12),
          Text('📺 La TV n’est plus connectée au salon', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.yellow)),
        ],
        if (room.perm) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(color: Pb.card.withValues(alpha: .7), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🔒 Salon permanent ${room.code}', style: Pb.t(16, weight: 600)),
              const SizedBox(height: 2),
              Text(
                'Pas de TV chez toi ? Le jeu s’affiche sur ton téléphone. Pour le voir en grand : '
                'ouvre ${serverBase().host}/tv sur un PC ou une TV → Salon permanent → Ouvrir.',
                style: Pb.t(14, color: Pb.muted),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: showScreen,
                activeThumbColor: Pb.pink,
                onChanged: onShowScreen,
                title: Text('Écran du jeu sur mon téléphone', style: Pb.t(15, weight: 600)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: phoneSfx,
                activeThumbColor: Pb.pink,
                onChanged: onPhoneSfx,
                title: Text('Sons et voix sur mon téléphone', style: Pb.t(15, weight: 600)),
              ),
              TextButton.icon(
                onPressed: onStats,
                icon: const Text('🏆'),
                label: Text('Classement de tous les temps', style: Pb.t(15, weight: 600)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 22),

        // ---- Jeu ----
        if (isHost) ...[
          Text('Choisis le jeu', style: Pb.t(18, weight: 600, color: Pb.muted)),
          const SizedBox(height: 10),
          _GamePicker(room: room, send: send),
          if (game != null)
            for (final e in game.options.entries)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(children: [
                  Text(e.value.label, style: Pb.t(16, weight: 600, color: Pb.muted)),
                  const Spacer(),
                  for (final v in e.value.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('$v', style: Pb.t(15, weight: 600)),
                        selected: room.options[e.key] == v,
                        showCheckmark: false,
                        selectedColor: Pb.pink,
                        backgroundColor: Pb.card,
                        side: BorderSide.none,
                        onSelected: (_) => send({'t': 'game_option', 'key': e.key, 'value': v}),
                      ),
                    ),
                ]),
              ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: game == null || !game.ready ? null : () => send({'t': 'start_game'}),
            child: Text(game == null ? 'Lancer' : 'Lancer ${game.title}'),
          ),
          const SizedBox(height: 10),
          // Plusieurs jeux d'affilée, avec un classement général
          OutlinedButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Pb.bg2,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              builder: (_) => SoireePicker(room: room, send: send),
            ),
            icon: const Text('🎯'),
            label: const Text('Soirée enchaînée'),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Pb.card.withValues(alpha: .7), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              if (game != null) Text(game.emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 6),
              Text(game?.title ?? '', style: Pb.t(22, weight: 700)),
              const SizedBox(height: 6),
              Text(
                '${room.host?.name ?? 'L’hôte'} choisit le jeu…\n${room.perm ? 'Ça va commencer !' : 'Regarde la TV !'}',
                textAlign: TextAlign.center,
                style: Pb.t(16, color: Pb.muted),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 22),

        // ---- Joueurs ----
        Text('Joueurs (${room.players.length}/${room.maxPlayers})', style: Pb.t(18, weight: 600, color: Pb.muted)),
        const SizedBox(height: 10),
        for (final p in room.players)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              PbAvatar(size: 40, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: !p.connected),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${p.name}${p.pid == room.hostPid ? '  👑' : ''}${p.pid == myPid ? '  (toi)' : ''}',
                  style: Pb.t(18, weight: 500, color: p.connected ? Pb.text : Pb.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (p.score > 0) Text(Pb.pts(p.score), style: Pb.t(16, weight: 600, color: Pb.yellow)),
              if (isHost && p.pid != myPid)
                IconButton(
                  tooltip: 'Retirer du salon',
                  icon: const Icon(Icons.close_rounded, color: Pb.muted, size: 20),
                  onPressed: () => _confirmKick(context, p),
                ),
            ]),
          ),
        const SizedBox(height: 18),
        PhoneTeams(room: room, myPid: myPid, isHost: isHost, send: send),

        const SizedBox(height: 26),
        TextButton(onPressed: onLeave, child: Text('Quitter le salon', style: Pb.t(16, color: Pb.muted))),
        const Center(child: HomeIconButton()),
      ],
    );
  }

  Future<void> _confirmKick(BuildContext context, PlayerView p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pb.bg2,
        title: Text('Retirer ${p.name} ?', style: Pb.t(22, weight: 600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok == true) send({'t': 'kick', 'pid': p.pid});
  }
}

/// Choix du jeu (hôte) : le jeu choisi, et la liste des jeux qui se déroule en le touchant
class _GamePicker extends StatefulWidget {
  const _GamePicker({required this.room, required this.send});
  final RoomView room;
  final void Function(Map<String, dynamic>) send;

  @override
  State<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends State<_GamePicker> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final cur = room.games.where((g) => g.id == room.selectedGame).firstOrNull ?? room.games.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _GameTile(
        g: cur,
        selected: true,
        trailing: AnimatedRotation(
          turns: _open ? .5 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.expand_more_rounded, color: Pb.text, size: 30),
        ),
        onTap: () => setState(() => _open = !_open),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !_open
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(children: [
                  for (final g in room.games)
                    if (g.id != cur.id)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _GameTile(
                          g: g,
                          selected: false,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.send({'t': 'select_game', 'game': g.id});
                            setState(() => _open = false);
                          },
                        ),
                      ),
                ]),
              ),
      ),
      const SizedBox(height: 8),
    ]);
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.g, required this.selected, required this.onTap, this.trailing});
  final GameInfo g;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Pb.cardHi : Pb.card.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Pb.pink : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Text(g.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: Pb.t(18, weight: 600)),
                Text(g.pitch, style: Pb.t(14, color: Pb.muted)),
              ]),
            ),
            if (!g.ready)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Pb.yellow.withValues(alpha: .15), borderRadius: BorderRadius.circular(10)),
                child: Text('Bientôt', style: Pb.t(12, weight: 600, color: Pb.yellow)),
              ),
            ?trailing,
          ]),
        ),
      ),
    );
  }
}

class _NetPill extends StatelessWidget {
  const _NetPill({required this.state});
  final ValueNotifier<NetState> state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: state,
      builder: (_, s, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: s == NetState.online
            ? const SizedBox.shrink()
            : Container(
                key: const ValueKey('off'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Pb.red.withValues(alpha: .9), borderRadius: BorderRadius.circular(20)),
                child: Text('Reconnexion…', style: Pb.t(14, weight: 600)),
              ),
      ),
    );
  }
}
