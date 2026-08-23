import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sur Android, google-services.json déclenche déjà une initialisation
  // native de Firebase ; réappeler initializeApp() planterait avec
  // "[core/duplicate-app]" si on ne vérifie pas d'abord.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
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
