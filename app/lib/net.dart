import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Serveur utilisé par l'appli Android TV (modifiable au build : --dart-define=PB_SERVER=…)
const kServer = String.fromEnvironment('PB_SERVER', defaultValue: 'https://party.foclabroc.duckdns.org');

/// Adresse du serveur : sur le web, même machine que le site, sauf si ?server=… est donné
/// (pratique pour tester l'appli en local contre le vrai serveur). En appli native : kServer.
Uri serverBase() {
  if (!kIsWeb) return Uri.parse(kServer);
  final b = Uri.base;
  final forced = b.queryParameters['server'];
  if (forced != null && forced.isNotEmpty) return Uri.parse(forced);
  return Uri(scheme: b.scheme, host: b.host, port: b.hasPort ? b.port : null);
}

Uri wsUri() {
  final s = serverBase();
  return s.replace(scheme: s.scheme == 'https' ? 'wss' : 'ws', path: '/ws');
}

String photoUrl(String path) => serverBase().replace(path: path).toString();

enum NetState { connecting, online, offline }

/// Connexion WebSocket qui se reconnecte toute seule.
/// [onOpen] est rappelé à chaque (re)connexion pour se réannoncer au serveur.
class PbSocket {
  PbSocket({required this.onOpen});

  final void Function(PbSocket s) onOpen;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final state = ValueNotifier(NetState.connecting);

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _retry;
  Timer? _ping;
  int _attempt = 0;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  void connect() {
    if (_disposed) return;
    _retry?.cancel();
    state.value = NetState.connecting;
    final ch = WebSocketChannel.connect(wsUri());
    _ch = ch;
    ch.ready.then((_) {
      if (_disposed || _ch != ch) return;
      _attempt = 0;
      state.value = NetState.online;
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) => send({'t': 'ping'}));
      onOpen(this);
    }).catchError((_) => _lost(ch));
    _sub = ch.stream.listen(
      (data) {
        try {
          final m = jsonDecode(data as String);
          if (m is Map<String, dynamic>) _messages.add(m);
        } catch (_) {}
      },
      onDone: () => _lost(ch),
      onError: (_) => _lost(ch),
      cancelOnError: true,
    );
  }

  void _lost(WebSocketChannel ch) {
    if (_disposed || _ch != ch) return;
    _ping?.cancel();
    _sub?.cancel();
    _ch = null;
    state.value = NetState.offline;
    // 0,5 s puis de plus en plus long, 8 s max
    final ms = (500 * (1 << _attempt.clamp(0, 4))).clamp(500, 8000);
    _attempt++;
    _retry = Timer(Duration(milliseconds: ms), connect);
  }

  void send(Map<String, dynamic> m) {
    if (state.value != NetState.online) return;
    _ch?.sink.add(jsonEncode(m));
  }

  /// Force une reconnexion immédiate (retour au premier plan du téléphone…)
  void kick() {
    if (state.value == NetState.offline) {
      _attempt = 0;
      connect();
    }
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _ping?.cancel();
    _sub?.cancel();
    _ch?.sink.close();
    _messages.close();
  }
}
