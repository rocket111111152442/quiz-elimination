class Player {
  final String uid;
  final String name;
  final bool alive;
  final int? eliminatedAtQuestion;
  final Map<int, int> answers;
  final String? avatar;
  final String? colorHex;

  const Player({
    required this.uid,
    required this.name,
    required this.alive,
    this.eliminatedAtQuestion,
    this.answers = const {},
    this.avatar,
    this.colorHex,
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
      avatar: map['avatar'] as String?,
      colorHex: map['colorHex'] as String?,
    );
  }
}
