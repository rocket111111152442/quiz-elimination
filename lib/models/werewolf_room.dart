enum WerewolfStatus {
  lobby,
  night,
  dayReveal,
  dayVote,
  voteReveal,
  hunterRevenge,
  finished,
}

WerewolfStatus werewolfStatusFromString(String value) {
  return WerewolfStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => WerewolfStatus.lobby,
  );
}

class WerewolfRoom {
  final String code;
  final String hostUid;
  final WerewolfStatus status;
  final int loupGarouCount;
  final Map<String, bool> roleEnabled;
  final int roundIndex;
  final List<String> nightOrder;
  final int nightStepIndex;
  final String? werewolfVictimUid;
  final String? salvateurProtectedUid;
  final String? salvateurLastProtectedUid;
  final bool witchHealUsed;
  final bool witchKillUsed;
  final List<String> loversUids;
  final bool villagePowersLost;
  final bool ancienImmunityUsed;
  final List<String> disenfranchisedUids;
  final List<String> lastNightDeaths;
  final String? lastVoteEliminated;
  final bool lastVoteTie;
  final bool lastVoteIdiotSurvived;
  final List<String> chainDeaths;
  final String? pendingActorUid;
  final WerewolfStatus? afterPending;
  final String? winner;

  const WerewolfRoom({
    required this.code,
    required this.hostUid,
    required this.status,
    required this.loupGarouCount,
    required this.roleEnabled,
    required this.roundIndex,
    required this.nightOrder,
    required this.nightStepIndex,
    this.werewolfVictimUid,
    this.salvateurProtectedUid,
    this.salvateurLastProtectedUid,
    required this.witchHealUsed,
    required this.witchKillUsed,
    required this.loversUids,
    required this.villagePowersLost,
    required this.ancienImmunityUsed,
    required this.disenfranchisedUids,
    required this.lastNightDeaths,
    this.lastVoteEliminated,
    required this.lastVoteTie,
    required this.lastVoteIdiotSurvived,
    required this.chainDeaths,
    this.pendingActorUid,
    this.afterPending,
    this.winner,
  });

  bool isRoleEnabled(String roleId) => roleEnabled[roleId] ?? false;

  String? get currentNightRole =>
      nightStepIndex >= 0 && nightStepIndex < nightOrder.length
      ? nightOrder[nightStepIndex]
      : null;

  factory WerewolfRoom.fromMap(String code, Map<String, dynamic> map) {
    final rawRoles = Map<String, dynamic>.from(
      map['roleEnabled'] as Map? ?? {},
    );
    return WerewolfRoom(
      code: code,
      hostUid: map['hostUid'] as String,
      status: werewolfStatusFromString(map['status'] as String? ?? 'lobby'),
      loupGarouCount: (map['loupGarouCount'] as num?)?.toInt() ?? 1,
      roleEnabled: rawRoles.map((k, v) => MapEntry(k, v as bool)),
      roundIndex: (map['roundIndex'] as num?)?.toInt() ?? 0,
      nightOrder: List<String>.from(map['nightOrder'] as List? ?? []),
      nightStepIndex: (map['nightStepIndex'] as num?)?.toInt() ?? 0,
      werewolfVictimUid: map['werewolfVictimUid'] as String?,
      salvateurProtectedUid: map['salvateurProtectedUid'] as String?,
      salvateurLastProtectedUid: map['salvateurLastProtectedUid'] as String?,
      witchHealUsed: map['witchHealUsed'] as bool? ?? false,
      witchKillUsed: map['witchKillUsed'] as bool? ?? false,
      loversUids: List<String>.from(map['loversUids'] as List? ?? []),
      villagePowersLost: map['villagePowersLost'] as bool? ?? false,
      ancienImmunityUsed: map['ancienImmunityUsed'] as bool? ?? false,
      disenfranchisedUids: List<String>.from(
        map['disenfranchisedUids'] as List? ?? [],
      ),
      lastNightDeaths: List<String>.from(map['lastNightDeaths'] as List? ?? []),
      lastVoteEliminated: map['lastVoteEliminated'] as String?,
      lastVoteTie: map['lastVoteTie'] as bool? ?? false,
      lastVoteIdiotSurvived: map['lastVoteIdiotSurvived'] as bool? ?? false,
      chainDeaths: List<String>.from(map['chainDeaths'] as List? ?? []),
      pendingActorUid: map['pendingActorUid'] as String?,
      afterPending: map['afterPending'] != null
          ? werewolfStatusFromString(map['afterPending'] as String)
          : null,
      winner: map['winner'] as String?,
    );
  }
}
