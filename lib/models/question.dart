class Question {
  final String text;
  final List<String> options;
  final int correctIndex;
  final int timeLimitSeconds;

  const Question({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.timeLimitSeconds = 20,
  });

  Map<String, dynamic> toMap() => {
    'text': text,
    'options': options,
    'correctIndex': correctIndex,
    'timeLimitSeconds': timeLimitSeconds,
  };

  factory Question.fromMap(Map<String, dynamic> map) => Question(
    text: map['text'] as String,
    options: List<String>.from(map['options'] as List),
    correctIndex: map['correctIndex'] as int,
    timeLimitSeconds: (map['timeLimitSeconds'] as num?)?.toInt() ?? 20,
  );
}
