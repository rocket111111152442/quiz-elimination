// ⚠️ Fichier généré normalement par `flutterfire configure`.
// Ce placeholder permet au projet de compiler avant que Firebase soit
// configuré, mais les valeurs ci-dessous sont fictives : l'app ne pourra
// pas se connecter à Firestore tant que tu n'auras pas lancé
// `flutterfire configure` (voir README.md, section "Configurer Firebase").
// La commande réécrit ce fichier avec les vraies valeurs de ton projet.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions n\'a pas été configuré pour le web. '
        'Relance `flutterfire configure`.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions ne supporte que Android pour ce projet.',
        );
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'REMPLACE_MOI',
    appId: 'REMPLACE_MOI',
    messagingSenderId: 'REMPLACE_MOI',
    projectId: 'REMPLACE_MOI',
    storageBucket: 'REMPLACE_MOI',
  );
}
