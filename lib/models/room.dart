import 'package:cloud_firestore/cloud_firestore.dart';

import 'question.dart';

enum RoomStatus { lobby, question, reveal, finished }

RoomStatus roomStatusFromString(String value) {
  return RoomStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => RoomStatus.lobby,
  );
}

class Room {
  final String code;
  final String hostUid;
  final RoomStatus status;
  final List<Question> questions;
  final int currentQuestionIndex;
  final Timestamp? questionStartedAt;

  const Room({
    required this.code,
    required this.hostUid,
    required this.status,
    required this.questions,
    required this.currentQuestionIndex,
    this.questionStartedAt,
  });

  Question? get currentQuestion =>
      currentQuestionIndex >= 0 && currentQuestionIndex < questions.length
      ? questions[currentQuestionIndex]
      : null;

  bool get isLastQuestion => currentQuestionIndex >= questions.length - 1;

  factory Room.fromMap(String code, Map<String, dynamic> map) => Room(
    code: code,
    hostUid: map['hostUid'] as String,
    status: roomStatusFromString(map['status'] as String? ?? 'lobby'),
    questions: (map['questions'] as List? ?? [])
        .map((q) => Question.fromMap(Map<String, dynamic>.from(q as Map)))
        .toList(),
    currentQuestionIndex: (map['currentQuestionIndex'] as num?)?.toInt() ?? -1,
    questionStartedAt: map['questionStartedAt'] as Timestamp?,
  );
}
