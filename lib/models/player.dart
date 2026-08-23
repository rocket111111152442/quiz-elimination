class Player {
  final String uid;
  final String name;
  final bool alive;
  final int? eliminatedAtQuestion;
  final Map<int, int> answers;
  final String? bike;
  final int lapsCompleted;
  final bool finished;
  final int? finishTimeMs;

  const Player({
    required this.uid,
    required this.name,
    required this.alive,
    this.eliminatedAtQuestion,
    this.answers = const {},
    this.bike,
    this.lapsCompleted = 0,
    this.finished = false,
    this.finishTimeMs,
  });

  int? answerFor(int questionIndex) => answers[questionIndex];

  factory Player.fromMap(String uid, Map<String, dynamic> map) {
    final rawAnswers = Map<String, dynamic>.from(map['answers'] as Map? ?? {});
    return Player(
      uid: uid,
      name: map['name'] as String? ?? 'Joueur',
      alive: map['alive'] as bool? ?? true,
      eliminatedAtQuestion: (map['eliminatedAtQuestion'] as num?)?.toInt(),
      answers: rawAnswers.map(
        (key, value) => MapEntry(int.parse(key), (value as num).toInt()),
      ),
      bike: map['bike'] as String?,
      lapsCompleted: (map['lapsCompleted'] as num?)?.toInt() ?? 0,
      finished: map['finished'] as bool? ?? false,
      finishTimeMs: (map['finishTimeMs'] as num?)?.toInt(),
    );
  }
}
