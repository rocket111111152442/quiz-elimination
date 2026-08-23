import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import 'home_screen.dart';

/// Shown the instant the app starts, while Firebase/AdMob/le son se
/// préparent en arrière-plan — sans cet écran, rien ne peut s'afficher
/// pendant ce temps-là et l'utilisateur voit un écran noir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } on FirebaseException catch (e) {
        // Sur Android, google-services.json déclenche déjà une
        // initialisation native de Firebase avant que Dart ne démarre ;
        // Firebase.apps ne le reflète pas encore à ce stade, donc on
        // intercepte l'erreur plutôt que de vérifier apps.isEmpty avant.
        if (e.code != 'duplicate-app') rethrow;
      }
      await AdService.initialize();
      await SoundService.instance.loadPreferences();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur de démarrage : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Quiz Élimination',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              if (_error != null)
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                )
              else
                SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
