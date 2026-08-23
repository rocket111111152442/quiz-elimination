enum GameType { quiz, undercover, werewolf }

GameType gameTypeFromString(String? value) {
  return GameType.values.firstWhere(
    (g) => g.name == value,
    orElse: () => GameType.quiz,
  );
}
