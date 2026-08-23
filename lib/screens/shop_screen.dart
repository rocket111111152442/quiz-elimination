import 'package:flutter/material.dart';

import '../data/shop_items.dart';
import '../models/player_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _profileService = ProfileService();
  final _authService = AuthService();

  String get _uid => _authService.currentUid!;

  Future<void> _tapAvatar(PlayerProfile profile, ShopAvatar item) async {
    final owned = profile.unlockedAvatars.contains(item.emoji);
    if (owned) {
      await _profileService.selectAvatar(_uid, item.emoji);
      return;
    }
    final unlocked = await _profileService.unlockAvatar(
      _uid,
      item.emoji,
      item.cost,
    );
    if (unlocked) {
      await _profileService.selectAvatar(_uid, item.emoji);
    } else if (mounted) {
      _showNotEnoughPoints();
    }
  }

  Future<void> _tapColor(PlayerProfile profile, ShopColorOption item) async {
    final owned = profile.unlockedColors.contains(item.hex);
    if (owned) {
      await _profileService.selectColor(_uid, item.hex);
      return;
    }
    final unlocked = await _profileService.unlockColor(
      _uid,
      item.hex,
      item.cost,
    );
    if (unlocked) {
      await _profileService.selectColor(_uid, item.hex);
    } else if (mounted) {
      _showNotEnoughPoints();
    }
  }

  void _showNotEnoughPoints() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pas assez de $currencyName ! Gagne des parties pour en avoir plus.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boutique')),
      body: SafeArea(
        child: StreamBuilder<PlayerProfile>(
          stream: _profileService.profileStream(_uid),
          builder: (context, snap) {
            final profile = snap.data ?? const PlayerProfile.empty();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(currencyEmoji, style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Text(
                        '${profile.points} $currencyName',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gagne des $currencyName en remportant une partie — plus il '
                  'y a de joueurs dans la partie que tu gagnes, plus tu en '
                  'gagnes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Avatars',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in shopAvatars)
                      _AvatarTile(
                        item: item,
                        owned: profile.unlockedAvatars.contains(item.emoji),
                        selected: profile.selectedAvatar == item.emoji,
                        onTap: () => _tapAvatar(profile, item),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Couleurs de pseudo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in shopColors)
                      _ColorTile(
                        item: item,
                        owned: profile.unlockedColors.contains(item.hex),
                        selected: profile.selectedColor == item.hex,
                        onTap: () => _tapColor(profile, item),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShopTileFrame extends StatelessWidget {
  final bool owned;
  final bool selected;
  final int cost;
  final VoidCallback onTap;
  final Widget child;

  const _ShopTileFrame({
    required this.owned,
    required this.selected,
    required this.cost,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.success : Colors.white24,
            width: selected ? 3 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: owned ? 1 : 0.35, child: child),
            if (!owned)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.white70),
                  Text(
                    '$cost',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            if (selected)
              const Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: AppColors.success,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  final ShopAvatar item;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.item,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopTileFrame(
      owned: owned,
      selected: selected,
      cost: item.cost,
      onTap: onTap,
      child: Text(item.emoji, style: const TextStyle(fontSize: 28)),
    );
  }
}

class _ColorTile extends StatelessWidget {
  final ShopColorOption item;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;

  const _ColorTile({
    required this.item,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopTileFrame(
      owned: owned,
      selected: selected,
      cost: item.cost,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
      ),
    );
  }
}
