# Quiz Élimination

Appli Android de quiz en temps réel pour jouer en classe : un·e élève (ou le
prof) crée une salle avec un code, toute la classe rejoint sur sa tablette,
et à chaque question **une mauvaise réponse élimine** — dernier·ère
survivant·e gagne.

- Un appareil = **hôte** : crée les questions, lance la partie, révèle les
  réponses et fait avancer le jeu.
- Les autres appareils = **joueurs** : rejoignent avec le code de la salle
  et un pseudo, répondent aux questions.
- Synchronisation en temps réel via **Firebase Firestore** (pas de serveur à
  héberger soi-même).

## 1. Configurer Firebase (obligatoire avant de lancer l'appli)

L'appli ne fonctionne pas tant que Firebase n'est pas configuré : le fichier
`lib/firebase_options.dart` contient des valeurs factices à remplacer.

1. Va sur [console.firebase.google.com](https://console.firebase.google.com)
   et crée un nouveau projet (gratuit).
2. Dans le projet, active :
   - **Firestore Database** (mode production).
   - **Authentication** → onglet Sign-in method → active **Anonyme**.
3. Installe les outils si besoin :
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
4. Depuis la racine du projet Flutter, lance :
   ```bash
   flutterfire configure
   ```
   Choisis ton projet Firebase et la plateforme **Android**. Cette commande
   régénère automatiquement `lib/firebase_options.dart` avec les vraies
   valeurs et ajoute `android/app/google-services.json`.
5. Déploie les règles de sécurité Firestore (dans `firestore.rules` à la
   racine du projet) :
   ```bash
   firebase deploy --only firestore:rules
   ```
   (si c'est la première fois, `firebase init firestore` te demandera un
   fichier de règles — pointe-le vers `firestore.rules`.)

## 2. Lancer l'appli en développement

```bash
flutter pub get
flutter run
```

Teste avec deux appareils/émulateurs : un pour l'hôte (« Créer une partie »),
un ou plusieurs pour les joueurs (« Rejoindre une partie » avec le code
affiché côté hôte).

## 3. Comment fonctionne une partie

Depuis l'accueil, **Créer une partie** ouvre d'abord un choix de mini-jeu
(Quiz Élimination ou Undercover, d'autres viendront s'ajouter à cette liste
plus tard). Chaque mini-jeu a son propre code de salle : les joueurs qui
rejoignent avec ce code atterrissent directement dans le bon jeu.

### Quiz Élimination

1. L'hôte choisit **Quiz Élimination**, ajoute ses questions (texte, 4
   réponses, la bonne réponse, un temps limite), puis **Lance la salle**.
2. Un code à 5 caractères s'affiche. Les élèves le saisissent dans
   **Rejoindre une partie** avec leur pseudo.
3. L'hôte appuie sur **Démarrer la partie**.
4. Pour chaque question : les joueurs répondent depuis leur tablette,
   l'hôte voit combien ont répondu, puis appuie sur **Révéler la réponse**.
   Tout joueur encore en jeu qui n'a pas la bonne réponse (ou n'a pas
   répondu à temps) est éliminé.
5. L'hôte enchaîne avec **Question suivante** jusqu'à la fin du quiz ou
   jusqu'à ce qu'il ne reste qu'un·e joueur·se — l'écran de résultats
   affiche alors le classement final.

Pour composer le quiz, l'hôte peut soit écrire ses propres questions
(**+ Question**), soit piocher dans la **banque de questions** intégrée
(environ 190 questions prêtes à l'emploi, réparties en 10 catégories :
culture générale, géographie, histoire, sciences, sport, cinéma, séries,
musique, jeux vidéo, nature & animaux) — les deux se mélangent librement
dans la même salle, et chaque question ajoutée reste modifiable ou
supprimable avant de lancer la partie.

### Undercover

Un mot est distribué à tout le monde en secret, sauf à un (ou plusieurs)
joueur·se **Undercover** qui reçoit un mot proche mais différent (ex. Civils
= « Pizza », Undercover = « Burger »). Personne ne sait qui a quel mot.

1. L'hôte choisit **Undercover**, sélectionne une catégorie de mots (ou
   « Aléatoire ») et le nombre d'Undercover, puis **Crée la salle**.
2. Les élèves rejoignent avec le code, comme pour le quiz.
3. L'hôte **Démarre la partie** (il faut au moins 3 joueurs). Chacun reçoit
   son mot secret sur son écran.
4. À chaque manche, les joueurs parlent chacun leur tour (l'ordre s'affiche
   à l'écran) et tapent **un seul mot** qui décrit leur mot secret sans le
   révéler directement. Tous les indices restent affichés, visibles de
   tout le monde. L'hôte appuie sur **Joueur suivant** après chaque tour.
5. Une fois tous les indices donnés, tout le monde **vote** en même temps
   pour désigner qui est, selon lui, l'Undercover. L'hôte appuie sur **Voir
   le résultat du vote** : le joueur avec le plus de votes est éliminé (en
   cas d'égalité, personne n'est éliminé ce tour-ci).
6. La partie continue en manches jusqu'à ce que tous les imposteurs soient
   démasqués (victoire des civils) ou qu'ils soient à égalité ou en
   supériorité numérique face aux civils restants (victoire des
   imposteurs). L'écran final révèle les deux mots et le rôle de chacun.

La banque de mots intégrée (`lib/data/word_bank.dart`) contient 100 paires
de mots réparties en 10 catégories (nourriture, animaux, lieux, sports,
technologie, métiers, transports, objets du quotidien, nature, loisirs) —
pour en ajouter, il suffit d'ajouter des `WordPair(...)` dans ce fichier.

**Mister White** (optionnel, à activer à la création du salon) : ce joueur
ne reçoit aucun mot du tout et doit bluffer uniquement grâce aux indices
des autres. S'il est démasqué par un vote, il a une dernière chance avant
que la partie continue : deviner le mot des civils. S'il trouve, il gagne
la partie à lui tout seul, peu importe le nombre de joueurs restants.

### Course de Motos

Course multijoueur en 2D vue du dessus, jusqu'à 8 pilotes en même temps.

1. L'hôte choisit **Course de Motos** — aucune configuration nécessaire,
   la salle est créée directement.
2. Les élèves rejoignent avec le code et choisissent leur moto parmi 4
   modèles aux caractéristiques différentes (vitesse, accélération,
   virage).
3. L'hôte **Démarre la course** : un décompte de 3 secondes s'affiche chez
   tout le monde, identique sur tous les écrans.
4. Chacun pilote sa moto avec deux boutons **◀ ▶** pour tourner et un
   bouton **GAZ** à maintenir pour accélérer — pensé pour être jouable au
   pouce sur tablette ou téléphone. Le circuit contient des flaques
   d'huile qui ralentissent, ainsi qu'un mini-boss qui patrouille sur une
   portion du circuit et repousse quiconque le touche.
5. Le premier arrivé après le nombre de tours prévu (3 par défaut) gagne.
   L'hôte suit un classement en direct et clique sur **Voir les
   résultats** une fois la course jugée terminée.

Techniquement, ce mini-jeu n'utilise aucun moteur de jeu externe (pas de
Flame, pas de Realtime Database) : tout est fait avec les outils déjà
présents dans Flutter (`CustomPainter` + un `Ticker` pour la boucle de
jeu), et la position de chaque joueur est simplement synchronisée via
Firestore plusieurs fois par seconde — ça évite d'avoir un nouveau
service Firebase à activer. Le circuit, les motos et les obstacles sont
définis dans `lib/game/race_track.dart` et `lib/data/bike_specs.dart` si
tu veux les ajuster (vitesse, forme du circuit, etc.).

## 4. Son et musique

Quatre petits effets sonores (validation, erreur, décompte, démarrage de
partie) sont déjà inclus dans `assets/sfx/`. Pour ajouter une musique de
fond (par exemple un morceau généré avec Suno) :

1. Exporte ton morceau en `.mp3` et nomme-le exactement `theme.mp3`.
2. Dépose-le dans le dossier `assets/music/` du projet (il existe déjà,
   avec juste un fichier `README.txt` dedans).
3. Relance `flutter pub get` puis `flutter run` — la musique se lance
   automatiquement en boucle sur l'écran d'accueil.

## 5. Publicités (AdMob)

Une bannière discrète s'affiche sur l'écran de résultats (jamais pendant
une question, pour ne pas gêner le jeu). Le projet utilise pour l'instant
les **ID de test officiels de Google** (`lib/services/ad_service.dart` et
`android/app/src/main/AndroidManifest.xml`) : ça fonctionne déjà tel quel
en développement, mais ne rapporte pas d'argent réel.

Pour passer en production :
1. Crée un compte [Google AdMob](https://admob.google.com) (gratuit).
2. Crée une appli AdMob puis une unité publicitaire "Bannière".
3. Remplace `bannerAdUnitId` dans `lib/services/ad_service.dart` et
   `com.google.android.gms.ads.APPLICATION_ID` dans
   `android/app/src/main/AndroidManifest.xml` par tes vrais ID.
4. Dans la Play Console, déclare l'audience de l'appli (probablement des
   mineurs si c'est pour une classe) — cela active automatiquement les
   règles Google adaptées (pas de publicité personnalisée pour les
   mineurs, etc.). Voir la [politique familles de Google Play](https://support.google.com/googleplay/android-developer/answer/9893335).

## 6. Paiements et idées de monétisation

Aucun paiement n'est câblé pour l'instant — mieux vaut ça qu'un faux
bouton "Payer" qui ne marche pas. Le chemin recommandé pour ajouter de
vrais achats :

1. Crée un [compte marchand Google Play](https://support.google.com/googleplay/android-developer/answer/9269274)
   (nécessite le compte développeur payant de l'étape 7).
2. Dans la Play Console, crée tes "produits" (achats intégrés) : un ID,
   un nom, un prix.
3. Ajoute le package [`in_app_purchase`](https://pub.dev/packages/in_app_purchase)
   au projet et branche-le sur les ID de produits créés à l'étape 2.

Idées de monétisation adaptées à ce type de jeu, sans rien qui pénalise
l'expérience de base :
- **Retirer les pubs** (achat unique) — l'option la plus simple et la
  mieux perçue.
- **Packs de questions premium** (par thème, ou questions créées par la
  communauté) en plus de la banque gratuite déjà incluse.
- **Thèmes visuels** ou animations de victoire supplémentaires
  (cosmétique, n'affecte jamais qui gagne).

À éviter si le public reste en grande partie mineur : rien qui ressemble
à une mécanique de type loot box, et aucune pression à payer pour
continuer à jouer.

## 7. Publier sur le Google Play Store

1. Crée un compte [Google Play Console](https://play.google.com/console)
   (25 $, paiement unique).
2. Génère une clé de signature et configure la release dans
   `android/app/build.gradle.kts` (remplace le `signingConfig` de debug par
   ta propre config de signature) — voir le guide officiel :
   https://docs.flutter.dev/deployment/android
3. Build le bundle de publication :
   ```bash
   flutter build appbundle
   ```
   Le fichier généré est dans `build/app/outputs/bundle/release/`.
4. Dans la Play Console, crée une nouvelle appli, remplis la fiche (nom,
   description, captures d'écran, icône), puis envoie l'`.aab` dans un
   canal de test interne d'abord pour vérifier que tout fonctionne, avant
   de publier en production.
5. Pense à changer `applicationId` dans
   `android/app/build.gradle.kts` si tu veux un identifiant différent —
   il ne peut plus être changé une fois publié.

## Structure du code

```
lib/
  data/         # question_bank.dart (~190 questions), word_bank.dart
                # (100 paires de mots Undercover), bike_specs.dart
  game/         # race_track.dart — circuit, obstacles, mini-boss
  models/       # Question, Room, Player, GameType, UndercoverRoom,
                # RacingRoom
  services/     # AuthService, RoomService (Firestore, les 3 mini-jeux),
                # SoundService, AdService
  screens/      # Home, choix du mini-jeu, création/rejoindre salle,
                # banque de questions, écrans hôte/joueur des 3 mini-jeux
  widgets/      # Boutons de réponse, minuteur, liste de joueurs, résultats
                # des 3 mini-jeux, bannière publicitaire
assets/sfx/     # Effets sonores (générés, libres de droits)
assets/music/   # Ta musique de fond (à ajouter toi-même, voir section 4)
firestore.rules # Règles de sécurité (l'hôte contrôle la partie, chaque
                # joueur ne peut écrire que sa propre réponse / son propre
                # indice / son propre vote / sa propre position)
```

D'autres mini-jeux viendront s'ajouter au même menu de choix à l'avenir —
chacun aura son propre écran hôte/joueur, exactement comme les trois
mini-jeux actuels.
