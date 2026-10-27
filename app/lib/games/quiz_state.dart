/// État public d'une partie de quiz, tel qu'envoyé par le serveur.
class QuizRank {
  QuizRank.fromJson(Map<String, dynamic> j)
      : pid = j['pid'] as String,
        score = (j['score'] as num).toInt(),
        rank = (j['rank'] as num).toInt(),
        gain = (j['gain'] as num?)?.toInt() ?? 0,
        prevRank = (j['prevRank'] as num?)?.toInt() ?? (j['rank'] as num).toInt(),
        streak = (j['streak'] as num?)?.toInt() ?? 0;

  final String pid;
  final int score;
  final int rank;
  final int gain;
  final int prevRank;
  final int streak;
}

class QuizState {
  QuizState.fromJson(Map<String, dynamic> j)
      : phase = j['phase'] as String,
        index = (j['index'] as num).toInt(),
        count = (j['count'] as num).toInt(),
        endsIn = (j['endsIn'] as num?)?.toInt() ?? 0,
        duration = (j['duration'] as num?)?.toInt() ?? 1,
        category = j['category'] as String?,
        difficulty = (j['difficulty'] as num?)?.toInt() ?? 1,
        question = j['question'] as String?,
        answers = [for (final a in (j['answers'] as List?) ?? const []) a as String],
        answered = {for (final a in (j['answered'] as List?) ?? const []) a as String},
        correct = (j['correct'] as num?)?.toInt(),
        picks = {
          for (final e in ((j['picks'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt(),
        },
        ranking = [for (final r in j['ranking'] as List) QuizRank.fromJson(r as Map<String, dynamic>)];

  final String phase; // intro, question, reveal, scores, podium
  final int index;
  final int count;
  final int endsIn;
  final int duration;
  final String? category;
  final int difficulty;
  final String? question;
  final List<String> answers;
  final Set<String> answered;
  final int? correct; // seulement à la révélation
  final Map<String, int> picks; // seulement à la révélation
  final List<QuizRank> ranking;

  /// Clé qui change à chaque nouvelle étape (pour relancer les animations)
  String get stepKey => '$phase-$index';
}

/// Ce que le serveur envoie en plus à chaque téléphone
class QuizYou {
  QuizYou.fromJson(Map<String, dynamic> j)
      : choice = (j['choice'] as num?)?.toInt(),
        gain = (j['gain'] as num?)?.toInt(),
        score = (j['score'] as num?)?.toInt() ?? 0,
        rank = (j['rank'] as num?)?.toInt(),
        streak = (j['streak'] as num?)?.toInt() ?? 0,
        players = (j['players'] as num?)?.toInt() ?? 0;

  final int? choice;
  final int? gain;
  final int score;
  final int? rank;
  final int streak;
  final int players;
}
