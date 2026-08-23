enum WerewolfTeam { loups, village }

/// A role card. [isUnique] means at most one copy is ever in play (the
/// exact same rule as the real card game: only one Voyante, one Sorcière,
/// etc.). Loup-Garou and Villageois are the only non-unique roles.
class WerewolfRoleDef {
  final String id;
  final String name;
  final String emoji;
  final WerewolfTeam team;
  final String description;
  final bool isUnique;

  const WerewolfRoleDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.team,
    required this.description,
    required this.isUnique,
  });
}

const werewolfRoles = [
  WerewolfRoleDef(
    id: 'loupGarou',
    name: 'Loup-Garou',
    emoji: '🐺',
    team: WerewolfTeam.loups,
    description:
        'Chaque nuit, les Loups-Garous se réveillent ensemble et choisissent '
        'en secret une victime à dévorer.',
    isUnique: false,
  ),
  WerewolfRoleDef(
    id: 'villageois',
    name: 'Villageois',
    emoji: '🧑‍🌾',
    team: WerewolfTeam.village,
    description:
        'Aucun pouvoir particulier : observe, discute et vote le jour pour '
        'démasquer les Loups-Garous.',
    isUnique: false,
  ),
  WerewolfRoleDef(
    id: 'voyante',
    name: 'Voyante',
    emoji: '🔮',
    team: WerewolfTeam.village,
    description: 'Chaque nuit, regarde en secret la carte d\'un autre joueur.',
    isUnique: true,
  ),
  WerewolfRoleDef(
    id: 'sorciere',
    name: 'Sorcière',
    emoji: '🧪',
    team: WerewolfTeam.village,
    description:
        'Possède une potion de vie (sauve une fois la victime des loups) et '
        'une potion de mort (élimine qui elle veut une fois dans la partie).',
    isUnique: true,
  ),
  WerewolfRoleDef(
    id: 'chasseur',
    name: 'Chasseur',
    emoji: '🏹',
    team: WerewolfTeam.village,
    description:
        'S\'il meurt, il tire immédiatement sur un joueur de son choix qui '
        'meurt aussi.',
    isUnique: true,
  ),
  WerewolfRoleDef(
    id: 'cupidon',
    name: 'Cupidon',
    emoji: '💘',
    team: WerewolfTeam.village,
    description:
        'La première nuit seulement, désigne deux joueurs amoureux (lui-même '
        'compris). Si l\'un meurt, l\'autre meurt de chagrin. S\'ils sont les '
        'deux derniers en vie, ils gagnent ensemble.',
    isUnique: true,
  ),
  WerewolfRoleDef(
    id: 'petiteFille',
    name: 'Petite Fille',
    emoji: '👧',
    team: WerewolfTeam.village,
    description:
        'Peut espionner pendant le tour des Loups-Garous et voir leurs votes '
        'en direct.',
    isUnique: true,
  ),
  WerewolfRoleDef(
    id: 'salvateur',
    name: 'Salvateur',
    emoji: '🛡️',
    team: WerewolfTeam.village,
    description:
        'Chaque nuit, protège un joueur de l\'attaque des loups (jamais deux '
        'nuits de suite le même).',
    isUnique: true,
  ),
  WerewolfRoleDef(
    id: 'ancien',
    name: 'Ancien',
    emoji: '👴',
    team: WerewolfTeam.village,
    description:
        'Survit à la toute première attaque des loups contre lui. Si le '
        'village le vote au lieu des loups, tous les pouvoirs spéciaux du '
        'village cessent de fonctionner pour le reste de la partie.',
    isUnique: true,
  ),
  WerewolfRoleDef(
    id: 'idiotDuVillage',
    name: 'Idiot du Village',
    emoji: '🤪',
    team: WerewolfTeam.village,
    description:
        'S\'il est voté par le village, il révèle sa carte et survit — mais '
        'perd le droit de voter ensuite.',
    isUnique: true,
  ),
  WerewolfRoleDef(
    id: 'boucEmissaire',
    name: 'Bouc Émissaire',
    emoji: '🐐',
    team: WerewolfTeam.village,
    description:
        'Si le vote du village est à égalité, c\'est lui qui est éliminé à '
        'la place d\'un revote.',
    isUnique: true,
  ),
];

WerewolfRoleDef werewolfRoleFor(String id) =>
    werewolfRoles.firstWhere((r) => r.id == id);
