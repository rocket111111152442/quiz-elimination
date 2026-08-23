enum GameType { quiz, undercover, werewolf, uno }

GameType gameTypeFromString(String? value) {
  return GameType.values.firstWhere(
    (g) => g.name == value,
    orElse: () => GameType.quiz,
  );
}
