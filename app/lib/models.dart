import 'dart:ui' show Color;

/// Ce que le serveur envoie de l'état d'un salon.
class PlayerView {
  PlayerView.fromJson(Map<String, dynamic> j)
      : pid = j['pid'] as String,
        name = j['name'] as String,
        emoji = (j['emoji'] as String?) ?? '🙂',
        color = (j['color'] as num?)?.toInt() ?? 0,
        photo = j['photo'] as String?,
        score = (j['score'] as num?)?.toInt() ?? 0,
        team = (j['team'] as num?)?.toInt(),
        connected = j['connected'] == true;

  final String pid;
  final String name;
  final String emoji;
  final int color;
  final String? photo;
  final int score;
  final int? team; // numéro d'équipe (équipes activées)
  final bool connected;
}

/// Équipes du salon (activées par l'hôte)
class TeamsView {
  TeamsView.fromJson(Map<String, dynamic> j)
      : count = (j['count'] as num).toInt(),
        names = [for (final n in j['names'] as List) n as String],
        scores = [for (final n in j['scores'] as List) (n as num).toInt()],
        lastGame = (j['last'] as Map?)?['game'] as String?,
        last = [for (final n in ((j['last'] as Map?)?['pts'] as List?) ?? const []) (n as num).toInt()];

  final int count;
  final List<String> names;
  final List<int> scores; // score de la soirée
  final String? lastGame;
  final List<int> last; // points de la dernière partie

  static const colors = [Color(0xFFFF5A5A), Color(0xFF4F8BFF), Color(0xFF3FCF7A), Color(0xFFFFD23F)];
  static Color color(int i) => colors[i % colors.length];
}

class SoireeRank {
  SoireeRank.fromJson(Map<String, dynamic> j)
      : pid = j['pid'] as String,
        score = (j['score'] as num).toInt(),
        rank = (j['rank'] as num).toInt();
  final String pid;
  final int score, rank;
}

/// Soirée enchaînée en cours
class SoireeView {
  SoireeView.fromJson(Map<String, dynamic> j)
      : games = [for (final g in j['games'] as List) g as String],
        index = (j['index'] as num).toInt(),
        step = j['step'] as String,
        endsIn = (j['endsIn'] as num?)?.toInt() ?? 0,
        duration = (j['duration'] as num?)?.toInt() ?? 1,
        ranking = [for (final r in j['ranking'] as List) SoireeRank.fromJson(r as Map<String, dynamic>)],
        teams = j['teams'] == null ? null : [for (final n in j['teams'] as List) (n as num).toInt()],
        last = j['last'] as String?;

  final List<String> games;
  final int index;
  final String step; // game | interlude | final
  final int endsIn, duration;
  final List<SoireeRank> ranking;
  final List<int>? teams;
  final String? last;
}

class GameInfo {
  GameInfo.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        emoji = j['emoji'] as String,
        min = (j['min'] as num).toInt(),
        ready = j['ready'] == true,
        pitch = (j['pitch'] as String?) ?? '',
        options = {
          for (final e in ((j['options'] as Map?) ?? const {}).entries)
            e.key as String: GameOption.fromJson(e.value as Map<String, dynamic>),
        };

  final String id;
  final String title;
  final String emoji;
  final int min;
  final bool ready;
  final String pitch;
  final Map<String, GameOption> options;
}

/// Réglage d'un jeu choisi par l'hôte (ex. nombre de questions)
class GameOption {
  GameOption.fromJson(Map<String, dynamic> j)
      : label = j['label'] as String,
        values = [for (final v in j['values'] as List) v as Object],
        def = j['def'] as Object;

  final String label;
  final List<Object> values;
  final Object def;
}

class RoomView {
  RoomView.fromJson(Map<String, dynamic> j)
      : code = j['code'] as String,
        phase = j['phase'] as String,
        perm = j['perm'] == true,
        hostPid = j['hostPid'] as String?,
        tvConnected = j['tvConnected'] == true,
        selectedGame = j['selectedGame'] as String?,
        maxPlayers = (j['maxPlayers'] as num?)?.toInt() ?? 10,
        options = Map<String, dynamic>.from((j['options'] as Map?) ?? const {}),
        live = j['game'] as Map<String, dynamic>?,
        teams = j['teams'] == null ? null : TeamsView.fromJson(j['teams'] as Map<String, dynamic>),
        soiree = j['soiree'] == null ? null : SoireeView.fromJson(j['soiree'] as Map<String, dynamic>),
        board = j['board'] == true,
        games = [for (final g in j['games'] as List) GameInfo.fromJson(g as Map<String, dynamic>)],
        players = [for (final p in j['players'] as List) PlayerView.fromJson(p as Map<String, dynamic>)];

  final String code;
  final String phase;
  final bool perm; // salon permanent (mot de passe, joueurs gardés)
  final String? hostPid;
  final bool tvConnected;
  final String? selectedGame;
  final int maxPlayers;
  final List<GameInfo> games;
  final List<PlayerView> players;
  final Map<String, dynamic> options; // réglages du jeu sélectionné
  final Map<String, dynamic>? live; // état public de la partie en cours (null au salon)
  final TeamsView? teams; // null = pas d'équipes
  final SoireeView? soiree; // null = pas de soirée enchaînée
  final bool board; // l'hôte affiche le classement sur la TV

  GameInfo? gameById(String id) => games.where((g) => g.id == id).firstOrNull;

  PlayerView? player(String pid) => players.where((p) => p.pid == pid).firstOrNull;

  GameInfo? get game => games.where((g) => g.id == selectedGame).firstOrNull;
  PlayerView? get host => players.where((p) => p.pid == hostPid).firstOrNull;
}
