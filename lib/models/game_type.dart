enum GameType { quiz, undercover, racing }

GameType gameTypeFromString(String? value) {
  return GameType.values.firstWhere(
    (g) => g.name == value,
    orElse: () => GameType.quiz,
  );
}
