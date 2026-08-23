import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/sound_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // Sur Android, google-services.json déclenche déjà une initialisation
    // native de Firebase avant que Dart ne démarre ; Firebase.apps ne le
    // reflète pas encore à ce stade, donc on intercepte l'erreur plutôt
    // que de vérifier apps.isEmpty au préalable.
    if (e.code != 'duplicate-app') rethrow;
  }
  await AdService.initialize();
  await SoundService.instance.loadPreferences();
  runApp(const QuizEliminationApp());
}

class QuizEliminationApp extends StatelessWidget {
  const QuizEliminationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Élimination',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
