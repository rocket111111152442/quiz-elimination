import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/shop_items.dart';
import '../models/player_profile.dart';
import '../services/auth_service.dart';
import '../services/iap_service.dart';
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
  final _iapService = IapService();
  String? _uid;
  bool _iapAvailable = false;
  List<ProductDetails> _products = [];
  final Set<String> _purchasing = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = await _authService.ensureSignedIn();
    if (!mounted) return;
    setState(() => _uid = uid);
    _iapService.start(uid);
    try {
      final available = await _iapService.isAvailable;
      final products = available
          ? await _iapService.loadProducts()
          : <ProductDetails>[];
      if (mounted) {
        setState(() {
          _iapAvailable = available;
          _products = products;
        });
      }
    } catch (_) {
      // Play Store indisponible (émulateur, app pas encore publiée...) —
      // la boutique de cosmétiques reste utilisable normalement.
    }
  }

  @override
  void dispose() {
    _iapService.dispose();
    super.dispose();
  }

  Future<void> _buyPack(ProductDetails product) async {
    setState(() => _purchasing.add(product.id));
    try {
      await _iapService.buy(product);
    } finally {
      if (mounted) setState(() => _purchasing.remove(product.id));
    }
  }

  Future<void> _tapAvatar(
    String uid,
    PlayerProfile profile,
    ShopAvatar item,
  ) async {
    final owned = profile.unlockedAvatars.contains(item.emoji);
    if (owned) {
      await _profileService.selectAvatar(uid, item.emoji);
      return;
    }
    final unlocked = await _profileService.unlockAvatar(
      uid,
      item.emoji,
      item.cost,
    );
    if (unlocked) {
      await _profileService.selectAvatar(uid, item.emoji);
    } else if (mounted) {
      _showNotEnoughPoints();
    }
  }

  Future<void> _tapColor(
    String uid,
    PlayerProfile profile,
    ShopColorOption item,
  ) async {
    final owned = profile.unlockedColors.contains(item.hex);
    if (owned) {
      await _profileService.selectColor(uid, item.hex);
      return;
    }
    final unlocked = await _profileService.unlockColor(
      uid,
      item.hex,
      item.cost,
    );
    if (unlocked) {
      await _profileService.selectColor(uid, item.hex);
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
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Boutique')),
      body: SafeArea(
        child: StreamBuilder<PlayerProfile>(
          stream: _profileService.profileStream(uid),
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
                        onTap: () => _tapAvatar(uid, profile, item),
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
                        onTap: () => _tapColor(uid, profile, item),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Acheter des Étincelles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (!_iapAvailable)
                  const Text(
                    'Achats indisponibles pour l\'instant (l\'appli doit '
                    'être publiée sur le Play Store).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  )
                else if (_products.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  for (final product in _products)
                    Card(
                      color: AppColors.surface,
                      child: ListTile(
                        title: Text(product.title),
                        subtitle: Text(product.description),
                        trailing: _purchasing.contains(product.id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () => _buyPack(product),
                                child: Text(product.price),
                              ),
                      ),
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
