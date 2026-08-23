import 'package:flutter/material.dart';

import '../data/shop_items.dart';
import '../models/player_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import 'create_game_picker_screen.dart';
import 'join_room_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();
  String? _uid;

  @override
  void initState() {
    super.initState();
    SoundService.instance.startMusic();
    _initProfile();
  }

  Future<void> _initProfile() async {
    try {
      final uid = await _authService.ensureSignedIn();
      await _profileService.ensureProfile(uid);
      if (mounted) setState(() => _uid = uid);
    } catch (_) {
      // Firebase indisponible (ex. tests) — l'appli continue sans solde
      // de points affiché, ce n'est pas bloquant pour jouer.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulsingBadge(),
                    const SizedBox(height: 24),
                    const Text(
                      'Quiz Élimination',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Réponds vite et bien, une erreur t\'élimine !',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateGamePickerScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Créer une partie'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const JoinRoomScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text('Rejoindre une partie'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ShopScreen()),
                        ),
                        icon: const Text(currencyEmoji),
                        label: const Text('Boutique'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_uid != null)
              Positioned(
                top: 0,
                left: 0,
                child: StreamBuilder<PlayerProfile>(
                  stream: _profileService.profileStream(_uid!),
                  builder: (context, snap) {
                    final points = snap.data?.points ?? 0;
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              currencyEmoji,
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$points',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Réglages',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  const _PulsingBadge();

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final glow = 20 + 16 * t;
        final scale = 1.0 + 0.04 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.danger],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: glow,
                  spreadRadius: 2 + 2 * t,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🔥', style: TextStyle(fontSize: 44)),
          ),
        );
      },
    );
  }
}
