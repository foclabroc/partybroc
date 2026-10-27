/// Ce que le serveur envoie de l'état d'un salon.
class PlayerView {
  PlayerView.fromJson(Map<String, dynamic> j)
      : pid = j['pid'] as String,
        name = j['name'] as String,
        emoji = (j['emoji'] as String?) ?? '🙂',
        color = (j['color'] as num?)?.toInt() ?? 0,
        photo = j['photo'] as String?,
        score = (j['score'] as num?)?.toInt() ?? 0,
        connected = j['connected'] == true;

  final String pid;
  final String name;
  final String emoji;
  final int color;
  final String? photo;
  final int score;
  final bool connected;
}

class GameInfo {
  GameInfo.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        emoji = j['emoji'] as String,
        min = (j['min'] as num).toInt(),
        ready = j['ready'] == true,
        pitch = (j['pitch'] as String?) ?? '';

  final String id;
  final String title;
  final String emoji;
  final int min;
  final bool ready;
  final String pitch;
}

class RoomView {
  RoomView.fromJson(Map<String, dynamic> j)
      : code = j['code'] as String,
        phase = j['phase'] as String,
        hostPid = j['hostPid'] as String?,
        tvConnected = j['tvConnected'] == true,
        selectedGame = j['selectedGame'] as String?,
        maxPlayers = (j['maxPlayers'] as num?)?.toInt() ?? 10,
        games = [for (final g in j['games'] as List) GameInfo.fromJson(g as Map<String, dynamic>)],
        players = [for (final p in j['players'] as List) PlayerView.fromJson(p as Map<String, dynamic>)];

  final String code;
  final String phase;
  final String? hostPid;
  final bool tvConnected;
  final String? selectedGame;
  final int maxPlayers;
  final List<GameInfo> games;
  final List<PlayerView> players;

  GameInfo? get game => games.where((g) => g.id == selectedGame).firstOrNull;
  PlayerView? get host => players.where((p) => p.pid == hostPid).firstOrNull;
}
