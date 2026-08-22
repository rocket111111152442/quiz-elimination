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

1. L'hôte appuie sur **Créer une partie**, ajoute ses questions (texte, 4
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

## 4. Publier sur le Google Play Store

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
  models/       # Question, Room, Player (structures de données)
  services/     # AuthService (connexion anonyme), RoomService (Firestore)
  screens/      # Home, création/rejoindre salle, écrans hôte/joueur
  widgets/      # Boutons de réponse, minuteur, liste de joueurs, résultats
firestore.rules # Règles de sécurité (seul l'hôte contrôle la partie,
                # chaque joueur ne peut écrire que sa propre réponse)
```
