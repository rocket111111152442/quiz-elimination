/// A bank of related-but-different word pairs for the Undercover game.
/// Civils get [civilWord], the undercover player(s) get [undercoverWord] —
/// close enough that a one-word clue can plausibly fit both, different
/// enough that the game stays fun to bluff and deduce.
class WordPair {
  final String category;
  final String civilWord;
  final String undercoverWord;

  const WordPair({
    required this.category,
    required this.civilWord,
    required this.undercoverWord,
  });
}

const List<String> wordCategories = [
  'Nourriture',
  'Animaux',
  'Lieux',
  'Sports',
  'Technologie',
  'Métiers',
  'Transports',
  'Objets du quotidien',
  'Nature',
  'Loisirs',
];

const List<WordPair> wordBank = [
  // ---------- Nourriture ----------
  WordPair(
    category: 'Nourriture',
    civilWord: 'Pizza',
    undercoverWord: 'Burger',
  ),
  WordPair(category: 'Nourriture', civilWord: 'Café', undercoverWord: 'Thé'),
  WordPair(
    category: 'Nourriture',
    civilWord: 'Chocolat',
    undercoverWord: 'Bonbon',
  ),
  WordPair(
    category: 'Nourriture',
    civilWord: 'Fromage',
    undercoverWord: 'Yaourt',
  ),
  WordPair(category: 'Nourriture', civilWord: 'Pomme', undercoverWord: 'Poire'),
  WordPair(category: 'Nourriture', civilWord: 'Riz', undercoverWord: 'Pâtes'),
  WordPair(
    category: 'Nourriture',
    civilWord: 'Croissant',
    undercoverWord: 'Baguette',
  ),
  WordPair(
    category: 'Nourriture',
    civilWord: 'Glace',
    undercoverWord: 'Sorbet',
  ),
  WordPair(
    category: 'Nourriture',
    civilWord: 'Soupe',
    undercoverWord: 'Salade',
  ),
  WordPair(
    category: 'Nourriture',
    civilWord: 'Gâteau',
    undercoverWord: 'Tarte',
  ),

  // ---------- Animaux ----------
  WordPair(category: 'Animaux', civilWord: 'Chien', undercoverWord: 'Chat'),
  WordPair(category: 'Animaux', civilWord: 'Lion', undercoverWord: 'Tigre'),
  WordPair(category: 'Animaux', civilWord: 'Aigle', undercoverWord: 'Faucon'),
  WordPair(category: 'Animaux', civilWord: 'Dauphin', undercoverWord: 'Requin'),
  WordPair(category: 'Animaux', civilWord: 'Cheval', undercoverWord: 'Âne'),
  WordPair(category: 'Animaux', civilWord: 'Serpent', undercoverWord: 'Lézard'),
  WordPair(category: 'Animaux', civilWord: 'Abeille', undercoverWord: 'Guêpe'),
  WordPair(category: 'Animaux', civilWord: 'Loup', undercoverWord: 'Renard'),
  WordPair(category: 'Animaux', civilWord: 'Ours', undercoverWord: 'Panda'),
  WordPair(
    category: 'Animaux',
    civilWord: 'Pingouin',
    undercoverWord: 'Manchot',
  ),

  // ---------- Lieux ----------
  WordPair(category: 'Lieux', civilWord: 'Plage', undercoverWord: 'Piscine'),
  WordPair(category: 'Lieux', civilWord: 'Montagne', undercoverWord: 'Colline'),
  WordPair(category: 'Lieux', civilWord: 'Forêt', undercoverWord: 'Jungle'),
  WordPair(category: 'Lieux', civilWord: 'École', undercoverWord: 'Université'),
  WordPair(category: 'Lieux', civilWord: 'Hôpital', undercoverWord: 'Clinique'),
  WordPair(category: 'Lieux', civilWord: 'Cinéma', undercoverWord: 'Théâtre'),
  WordPair(
    category: 'Lieux',
    civilWord: 'Musée',
    undercoverWord: 'Bibliothèque',
  ),
  WordPair(
    category: 'Lieux',
    civilWord: 'Restaurant',
    undercoverWord: 'Fast-food',
  ),
  WordPair(category: 'Lieux', civilWord: 'Aéroport', undercoverWord: 'Gare'),
  WordPair(category: 'Lieux', civilWord: 'Château', undercoverWord: 'Palais'),

  // ---------- Sports ----------
  WordPair(category: 'Sports', civilWord: 'Football', undercoverWord: 'Rugby'),
  WordPair(
    category: 'Sports',
    civilWord: 'Basketball',
    undercoverWord: 'Volleyball',
  ),
  WordPair(
    category: 'Sports',
    civilWord: 'Natation',
    undercoverWord: 'Plongée',
  ),
  WordPair(
    category: 'Sports',
    civilWord: 'Tennis',
    undercoverWord: 'Badminton',
  ),
  WordPair(category: 'Sports', civilWord: 'Boxe', undercoverWord: 'Karaté'),
  WordPair(category: 'Sports', civilWord: 'Ski', undercoverWord: 'Snowboard'),
  WordPair(
    category: 'Sports',
    civilWord: 'Vélo',
    undercoverWord: 'Trottinette',
  ),
  WordPair(category: 'Sports', civilWord: 'Golf', undercoverWord: 'Bowling'),
  WordPair(
    category: 'Sports',
    civilWord: 'Escalade',
    undercoverWord: 'Randonnée',
  ),
  WordPair(category: 'Sports', civilWord: 'Judo', undercoverWord: 'Taekwondo'),

  // ---------- Technologie ----------
  WordPair(
    category: 'Technologie',
    civilWord: 'Smartphone',
    undercoverWord: 'Tablette',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'Instagram',
    undercoverWord: 'TikTok',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'PlayStation',
    undercoverWord: 'Xbox',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'Ordinateur',
    undercoverWord: 'Laptop',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'WhatsApp',
    undercoverWord: 'Messenger',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'YouTube',
    undercoverWord: 'Netflix',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'Wifi',
    undercoverWord: 'Bluetooth',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'Casque',
    undercoverWord: 'Écouteurs',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'Drone',
    undercoverWord: 'Hélicoptère',
  ),
  WordPair(
    category: 'Technologie',
    civilWord: 'Robot',
    undercoverWord: 'Androïde',
  ),

  // ---------- Métiers ----------
  WordPair(
    category: 'Métiers',
    civilWord: 'Docteur',
    undercoverWord: 'Infirmier',
  ),
  WordPair(
    category: 'Métiers',
    civilWord: 'Pompier',
    undercoverWord: 'Policier',
  ),
  WordPair(
    category: 'Métiers',
    civilWord: 'Professeur',
    undercoverWord: 'Directeur',
  ),
  WordPair(
    category: 'Métiers',
    civilWord: 'Cuisinier',
    undercoverWord: 'Boulanger',
  ),
  WordPair(category: 'Métiers', civilWord: 'Pilote', undercoverWord: 'Steward'),
  WordPair(category: 'Métiers', civilWord: 'Avocat', undercoverWord: 'Juge'),
  WordPair(
    category: 'Métiers',
    civilWord: 'Architecte',
    undercoverWord: 'Ingénieur',
  ),
  WordPair(
    category: 'Métiers',
    civilWord: 'Chanteur',
    undercoverWord: 'Musicien',
  ),
  WordPair(
    category: 'Métiers',
    civilWord: 'Acteur',
    undercoverWord: 'Réalisateur',
  ),
  WordPair(
    category: 'Métiers',
    civilWord: 'Fermier',
    undercoverWord: 'Jardinier',
  ),

  // ---------- Transports ----------
  WordPair(
    category: 'Transports',
    civilWord: 'Voiture',
    undercoverWord: 'Moto',
  ),
  WordPair(category: 'Transports', civilWord: 'Train', undercoverWord: 'Métro'),
  WordPair(
    category: 'Transports',
    civilWord: 'Avion',
    undercoverWord: 'Hélicoptère',
  ),
  WordPair(category: 'Transports', civilWord: 'Bus', undercoverWord: 'Tramway'),
  WordPair(
    category: 'Transports',
    civilWord: 'Bateau',
    undercoverWord: 'Voilier',
  ),
  WordPair(
    category: 'Transports',
    civilWord: 'Vélo',
    undercoverWord: 'Skateboard',
  ),
  WordPair(
    category: 'Transports',
    civilWord: 'Camion',
    undercoverWord: 'Fourgon',
  ),
  WordPair(category: 'Transports', civilWord: 'Taxi', undercoverWord: 'Uber'),
  WordPair(
    category: 'Transports',
    civilWord: 'Fusée',
    undercoverWord: 'Satellite',
  ),
  WordPair(
    category: 'Transports',
    civilWord: 'Roller',
    undercoverWord: 'Trottinette',
  ),

  // ---------- Objets du quotidien ----------
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Stylo',
    undercoverWord: 'Crayon',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Livre',
    undercoverWord: 'Cahier',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Montre',
    undercoverWord: 'Réveil',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Parapluie',
    undercoverWord: 'Manteau',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Miroir',
    undercoverWord: 'Lunettes',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Clé',
    undercoverWord: 'Cadenas',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Valise',
    undercoverWord: 'Sac à dos',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Téléphone',
    undercoverWord: 'Ordinateur',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Chaise',
    undercoverWord: 'Canapé',
  ),
  WordPair(
    category: 'Objets du quotidien',
    civilWord: 'Lampe',
    undercoverWord: 'Bougie',
  ),

  // ---------- Nature ----------
  WordPair(category: 'Nature', civilWord: 'Soleil', undercoverWord: 'Lune'),
  WordPair(category: 'Nature', civilWord: 'Pluie', undercoverWord: 'Neige'),
  WordPair(category: 'Nature', civilWord: 'Océan', undercoverWord: 'Lac'),
  WordPair(category: 'Nature', civilWord: 'Volcan', undercoverWord: 'Montagne'),
  WordPair(
    category: 'Nature',
    civilWord: 'Arc-en-ciel',
    undercoverWord: 'Aurore boréale',
  ),
  WordPair(category: 'Nature', civilWord: 'Désert', undercoverWord: 'Savane'),
  WordPair(
    category: 'Nature',
    civilWord: 'Rivière',
    undercoverWord: 'Ruisseau',
  ),
  WordPair(category: 'Nature', civilWord: 'Étoile', undercoverWord: 'Planète'),
  WordPair(
    category: 'Nature',
    civilWord: 'Nuage',
    undercoverWord: 'Brouillard',
  ),
  WordPair(category: 'Nature', civilWord: 'Tempête', undercoverWord: 'Orage'),

  // ---------- Loisirs ----------
  WordPair(
    category: 'Loisirs',
    civilWord: 'Jeux vidéo',
    undercoverWord: 'Jeux de société',
  ),
  WordPair(
    category: 'Loisirs',
    civilWord: 'Peinture',
    undercoverWord: 'Dessin',
  ),
  WordPair(category: 'Loisirs', civilWord: 'Danse', undercoverWord: 'Chant'),
  WordPair(
    category: 'Loisirs',
    civilWord: 'Lecture',
    undercoverWord: 'Écriture',
  ),
  WordPair(category: 'Loisirs', civilWord: 'Pêche', undercoverWord: 'Chasse'),
  WordPair(
    category: 'Loisirs',
    civilWord: 'Camping',
    undercoverWord: 'Randonnée',
  ),
  WordPair(
    category: 'Loisirs',
    civilWord: 'Puzzle',
    undercoverWord: 'Mots croisés',
  ),
  WordPair(category: 'Loisirs', civilWord: 'Guitare', undercoverWord: 'Piano'),
  WordPair(
    category: 'Loisirs',
    civilWord: 'Photographie',
    undercoverWord: 'Vidéo',
  ),
  WordPair(
    category: 'Loisirs',
    civilWord: 'Jardinage',
    undercoverWord: 'Bricolage',
  ),
];
