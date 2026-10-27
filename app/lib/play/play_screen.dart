import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../net.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
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
  String? _formError;

  // Session en cours (pour revenir après une coupure)
  String? _sCode;
  String? _sToken;
  String? _myPid;
  RoomView? _room;
  bool _pendingJoin = false;

  @override
  void initState() {
    super.initState();
    _sock = PbSocket(onOpen: _onOpen);
    _sub = _sock.messages.listen(_onMessage);
    _life = AppLifecycleListener(onResume: _sock.kick);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _profile = await Profile.load(prefs);
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
      s.send({'t': 'join', 'code': _code.text.trim(), ..._profile.toMessage()});
    }
  }

  void _clearSession() {
    _sCode = null;
    _sToken = null;
    _myPid = null;
    _prefs?.remove('s_code');
    _prefs?.remove('s_token');
  }

  void _backToForm(String? msg) {
    _clearSession();
    setState(() {
      _room = null;
      _pendingJoin = false;
      _step = _Step.form;
      _formError = msg;
    });
  }

  void _onMessage(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'joined':
        _sCode = m['code'] as String;
        _sToken = m['token'] as String;
        _myPid = m['pid'] as String;
        _prefs?.setString('s_code', _sCode!);
        _prefs?.setString('s_token', _sToken!);
        _pendingJoin = false;
        HapticFeedback.mediumImpact();
        setState(() => _step = _Step.lobby);
      case 'room':
        setState(() => _room = RoomView.fromJson(m['room'] as Map<String, dynamic>));
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
    final code = _code.text.trim().toUpperCase();
    if (code.length != 4) return setState(() => _formError = 'Le code fait 4 lettres (il est affiché sur la TV)');
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
      _sock.send({'t': 'join', 'code': code, ..._profile.toMessage()});
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
    _life.dispose();
    _sock.dispose();
    _code.dispose();
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
              child: Stack(children: [
                Positioned.fill(child: _body()),
                Positioned(top: 8, left: 0, right: 0, child: Center(child: _NetPill(state: _sock.state))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

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
        return _LobbyView(
          room: room,
          myPid: _myPid,
          onEdit: _editProfile,
          onLeave: _leave,
          send: _sock.send,
        );
    }
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
      children: [
        const Center(child: PbLogo(size: 38)),
        const SizedBox(height: 26),
        Text('Code affiché sur la TV', style: Pb.t(16, weight: 600, color: Pb.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          maxLength: 4,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
            TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
          ],
          style: Pb.t(40, weight: 700, color: Pb.yellow).copyWith(letterSpacing: 14),
          decoration: const InputDecoration(hintText: 'ABCD', counterText: ''),
        ),
        const SizedBox(height: 24),
        ProfileEditor(profile: _profile, onChanged: () => setState(() {})),
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
  });

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
        if (!room.tvConnected) ...[
          const SizedBox(height: 12),
          Text('📺 La TV n’est plus connectée au salon', textAlign: TextAlign.center, style: Pb.t(15, color: Pb.yellow)),
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
              if (isHost && p.pid != myPid)
                IconButton(
                  tooltip: 'Retirer du salon',
                  icon: const Icon(Icons.close_rounded, color: Pb.muted, size: 20),
                  onPressed: () => _confirmKick(context, p),
                ),
            ]),
          ),
        const SizedBox(height: 18),

        // ---- Jeu ----
        if (isHost) ...[
          Text('Choisis le jeu', style: Pb.t(18, weight: 600, color: Pb.muted)),
          const SizedBox(height: 10),
          for (final g in room.games)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GameTile(g: g, selected: g.id == room.selectedGame, onTap: () {
                HapticFeedback.selectionClick();
                send({'t': 'select_game', 'game': g.id});
              }),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: game == null ? null : () => send({'t': 'start_game'}),
            child: Text(game == null ? 'Lancer' : 'Lancer ${game.title}'),
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
                '${room.host?.name ?? 'L’hôte'} choisit le jeu…\nRegarde la TV !',
                textAlign: TextAlign.center,
                style: Pb.t(16, color: Pb.muted),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 26),
        TextButton(onPressed: onLeave, child: Text('Quitter le salon', style: Pb.t(16, color: Pb.muted))),
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

class _GameTile extends StatelessWidget {
  const _GameTile({required this.g, required this.selected, required this.onTap});
  final GameInfo g;
  final bool selected;
  final VoidCallback onTap;

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
