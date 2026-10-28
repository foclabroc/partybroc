import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Réactions proposées (même liste que le serveur)
const kReactions = ['😂', '👏', '❤️', '😮', '🔥', '👍', '😱', '🎉'];

class ChatMsg {
  ChatMsg.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        pid = j['pid'] as String? ?? '',
        name = j['name'] as String? ?? '?',
        emoji = j['emoji'] as String? ?? '🙂',
        color = (j['color'] as num?)?.toInt() ?? 0,
        text = j['text'] as String? ?? '',
        seen = DateTime.now();

  final int id;
  final String pid, name, emoji, text;
  final int color;
  final DateTime seen; // arrivée sur cet écran (pour l'effacer au bout de quelques secondes)
}

class FloatReact {
  FloatReact(this.e, this.name, this.color, this.x) : born = DateTime.now();
  final String e, name;
  final int color;
  final double x; // 0–1, position horizontale
  final DateTime born;
  final key = UniqueKey();
}

/// Messages et réactions en direct du salon (TV et téléphones)
class LiveFeed extends ChangeNotifier {
  LiveFeed._();
  static final instance = LiveFeed._();

  final log = <ChatMsg>[]; // 30 derniers messages
  final reacts = <FloatReact>[];
  int unread = 0;
  final _rnd = Random();
  Timer? _tick;

  /// Renvoie true si le message était pour nous
  bool handle(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'chat_log':
        log
          ..clear()
          ..addAll([for (final i in (m['items'] as List? ?? const [])) ChatMsg.fromJson(i as Map<String, dynamic>)]);
        // l'historique n'apparaît pas en bulles : on le date d'avant
        unread = 0;
        _old = log.map((e) => e.id).toSet();
      case 'chat':
        final c = ChatMsg.fromJson(m);
        if (log.any((e) => e.id == c.id)) return true;
        log.add(c);
        if (log.length > 30) log.removeAt(0);
        unread++;
      case 'react':
        if (reacts.length > 40) reacts.removeAt(0);
        reacts.add(FloatReact(m['e'] as String? ?? '👍', m['name'] as String? ?? '', (m['color'] as num?)?.toInt() ?? 0,
            .08 + _rnd.nextDouble() * .84));
      default:
        return false;
    }
    _ensureTick();
    notifyListeners();
    return true;
  }

  Set<int> _old = {};

  /// Messages à afficher en bulles (arrivés il y a moins de [age])
  List<ChatMsg> recent(Duration age, {int max = 4}) {
    final now = DateTime.now();
    final l = log.where((c) => !_old.contains(c.id) && now.difference(c.seen) < age).toList();
    return l.length > max ? l.sublist(l.length - max) : l;
  }

  void markRead() {
    unread = 0;
    notifyListeners();
  }

  void reset() {
    log.clear();
    reacts.clear();
    unread = 0;
    _old = {};
    notifyListeners();
  }

  // Tant qu'il y a quelque chose à l'écran, on rafraîchit pour l'effacer à temps
  void _ensureTick() {
    _tick ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      final now = DateTime.now();
      reacts.removeWhere((r) => now.difference(r.born) > const Duration(milliseconds: 3200));
      notifyListeners();
      if (reacts.isEmpty && log.every((c) => now.difference(c.seen) > const Duration(seconds: 12))) {
        _tick?.cancel();
        _tick = null;
      }
    });
  }
}

/// Couche par-dessus l'écran : réactions qui montent, bulles des derniers messages.
/// [scale] = 1 sur la toile TV 1920×1080, plus petit sur un téléphone.
class LiveLayer extends StatelessWidget {
  const LiveLayer({super.key, this.scale = 1, this.bubbles = true, this.bubbleBottom = 150});
  final double scale;
  final bool bubbles;
  final double bubbleBottom;

  @override
  Widget build(BuildContext context) {
    final feed = LiveFeed.instance;
    return IgnorePointer(
      child: RepaintBoundary(child: ListenableBuilder(
        listenable: feed,
        builder: (context, _) => LayoutBuilder(builder: (context, c) {
          return Stack(children: [
            for (final r in feed.reacts) _Rise(key: r.key, r: r, w: c.maxWidth, h: c.maxHeight, scale: scale),
            if (bubbles)
              Positioned(
                right: 36 * scale,
                bottom: bubbleBottom * scale,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 620 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final m in feed.recent(const Duration(seconds: 9))) ChatBubble(key: ValueKey(m.id), m: m, scale: scale)],
                  ),
                ),
              ),
          ]);
        }),
      )),
    );
  }
}

/// Une réaction : monte en ondulant et s'efface
class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.r, required this.w, required this.h, required this.scale});
  final FloatReact r;
  final double w, h, scale;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 3000),
      builder: (_, v, _) {
        final y = h - 60 * scale - v * h * .55;
        final x = r.x * w + sin(v * 9) * 26 * scale;
        final o = v < .7 ? 1.0 : (1 - (v - .7) / .3);
        return Positioned(
          left: x - 50 * scale,
          top: y,
          child: Opacity(
            opacity: o.clamp(0, 1),
            child: Transform.scale(
              scale: v < .15 ? .4 + v * 4 : 1,
              child: SizedBox(
                width: 100 * scale,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(r.e, style: TextStyle(fontSize: 78 * scale, height: 1.1)),
                  if (r.name.isNotEmpty && scale > .5)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 2 * scale),
                      decoration: BoxDecoration(color: Pb.playerColor(r.color), borderRadius: BorderRadius.circular(20)),
                      child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(20 * scale, weight: 700, color: Pb.bg)),
                    ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.m, this.scale = 1});
  final ChatMsg m;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.translate(offset: Offset((1 - v) * 60 * scale, 0), child: child)),
      child: Container(
        margin: EdgeInsets.only(top: 12 * scale),
        padding: EdgeInsets.fromLTRB(14 * scale, 10 * scale, 22 * scale, 12 * scale),
        decoration: BoxDecoration(
          color: Pb.cardHi.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(28 * scale),
          border: Border.all(color: Pb.playerColor(m.color), width: 3 * scale),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 18 * scale)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.emoji, style: TextStyle(fontSize: 40 * scale, height: 1.1)),
          SizedBox(width: 12 * scale),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(m.name, style: Pb.t(22 * scale, weight: 700, color: Pb.playerColor(m.color))),
              Text(m.text, style: Pb.t(30 * scale, weight: 500)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Barre du téléphone : réactions d'un appui, bouton des messages
class PhoneChatBar extends StatelessWidget {
  const PhoneChatBar({super.key, required this.send, required this.canChat});
  final void Function(Map<String, dynamic>) send;
  final bool canChat;

  @override
  Widget build(BuildContext context) {
    final feed = LiveFeed.instance;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      decoration: BoxDecoration(color: Pb.bg2.withValues(alpha: .92), border: const Border(top: BorderSide(color: Pb.cardHi))),
      child: Row(children: [
        for (final e in kReactions)
          Expanded(
            child: InkResponse(
              radius: 24,
              onTap: () => send({'t': 'react', 'e': e}),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
              ),
            ),
          ),
        ListenableBuilder(
          listenable: feed,
          builder: (context, _) => Badge(
            isLabelVisible: feed.unread > 0,
            label: Text('${feed.unread}'),
            backgroundColor: Pb.pink,
            child: IconButton.filledTonal(
              tooltip: 'Messages',
              onPressed: () => _openChat(context),
              icon: const Icon(Icons.chat_bubble_rounded, size: 22),
            ),
          ),
        ),
      ]),
    );
  }

  void _openChat(BuildContext context) {
    LiveFeed.instance.markRead();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pb.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ChatSheet(send: send, canChat: canChat),
    );
  }
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet({required this.send, required this.canChat});
  final void Function(Map<String, dynamic>) send;
  final bool canChat;

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _text = TextEditingController();
  static const _quick = ['Bravo ! 👏', 'Trop fort 😎', 'Oh non 😱', 'Encore une ! 🔁', 'GG 🏆', 'Je triche pas 😇'];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send(String t) {
    final s = t.trim();
    if (s.isEmpty) return;
    widget.send({'t': 'chat', 'text': s});
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final feed = LiveFeed.instance;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: Column(children: [
            const SizedBox(height: 14),
            Text('Messages', style: Pb.t(22, weight: 700)),
            Expanded(
              child: ListenableBuilder(
                listenable: feed,
                builder: (context, _) {
                  final items = feed.log.reversed.toList();
                  if (items.isEmpty) {
                    return Center(child: Text('Pas encore de message.\nDis bonjour ! 👋', textAlign: TextAlign.center, style: Pb.t(17, color: Pb.muted)));
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final m = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(TextSpan(children: [
                              TextSpan(text: '${m.name}  ', style: Pb.t(16, weight: 700, color: Pb.playerColor(m.color))),
                              TextSpan(text: m.text, style: Pb.t(17)),
                            ])),
                          ),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
            if (!widget.canChat)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Pas de messages pendant le dessin (ce serait de la triche 😉). Les réactions, oui !',
                    textAlign: TextAlign.center, style: Pb.t(15, color: Pb.yellow)),
              )
            else ...[
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final q in _quick)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(q, style: Pb.t(14, weight: 600)),
                          backgroundColor: Pb.card,
                          side: BorderSide.none,
                          onPressed: () => _send(q),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLength: 80,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      style: Pb.t(17),
                      decoration: const InputDecoration(hintText: 'Ton message…', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _send(_text.text),
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(backgroundColor: Pb.pink, minimumSize: const Size(52, 52)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
