import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/player_profile.dart';

/// Minimum time between two ad-reward credits — mostly a safety net
/// against a double-fired reward callback, not a serious anti-abuse cap
/// (watching another full ad already costs real time).
const adRewardCooldown = Duration(seconds: 20);

class ProfileService {
  // Lazy on purpose, same reasoning as AuthService._auth.
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('profiles').doc(uid);

  /// Creates the profile doc the first time a device is seen. Safe to call
  /// repeatedly. Must run on the profile owner's own device — the
  /// Firestore rules only let a uid create its own profile.
  Future<void> ensureProfile(String uid) async {
    final snap = await _doc(uid).get();
    if (snap.exists) return;
    await _doc(uid).set({
      'points': 0,
      'unlockedAvatars': <String>[],
      'unlockedColors': <String>[],
      'selectedAvatar': null,
      'selectedColor': null,
      'lastAdRewardAt': null,
    });
  }

  Stream<PlayerProfile> profileStream(String uid) {
    return _doc(uid).snapshots().map((snap) => _fromSnap(snap.data()));
  }

  Future<PlayerProfile> getProfile(String uid) async {
    final snap = await _doc(uid).get();
    return _fromSnap(snap.data());
  }

  PlayerProfile _fromSnap(Map<String, dynamic>? data) =>
      data == null ? const PlayerProfile.empty() : PlayerProfile.fromMap(data);

  /// Credits points to any player's profile — this is routinely called
  /// from a *different* device (whoever's device resolves the end of the
  /// game awards every winner, not just themselves), so the Firestore
  /// rules only allow this kind of write to increase `points` and touch
  /// nothing else. Swallows errors on purpose: a hiccup crediting a bonus
  /// currency must never break the actual game-ending flow that calls it.
  Future<void> awardPoints(String uid, int amount) async {
    if (amount <= 0) return;
    try {
      await _doc(uid).update({'points': FieldValue.increment(amount)});
    } catch (_) {
      // Le profil du joueur n'existe peut-être pas encore (jamais passé
      // par l'écran d'accueil) — tant pis pour ces points, la partie ne
      // doit pas planter pour autant.
    }
  }

  Future<void> awardPointsToAll(Iterable<String> uids, int amount) async {
    for (final uid in uids) {
      await awardPoints(uid, amount);
    }
  }

  Future<bool> unlockAvatar(String uid, String avatarId, int cost) =>
      _unlock(uid, field: 'unlockedAvatars', itemId: avatarId, cost: cost);

  Future<bool> unlockColor(String uid, String colorId, int cost) =>
      _unlock(uid, field: 'unlockedColors', itemId: colorId, cost: cost);

  Future<bool> _unlock(
    String uid, {
    required String field,
    required String itemId,
    required int cost,
  }) async {
    final ref = _doc(uid);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final points = (data['points'] as num?)?.toInt() ?? 0;
      final unlocked = List<String>.from(data[field] as List? ?? []);
      if (unlocked.contains(itemId)) return true;
      if (points < cost) return false;
      tx.update(ref, {
        'points': points - cost,
        field: [...unlocked, itemId],
      });
      return true;
    });
  }

  /// Credits [amount] points for watching a rewarded ad, on the viewer's
  /// own device — self-write, so this needs no special Firestore rule.
  /// Returns false without crediting anything if called again inside the
  /// cooldown window (guards against a double-fired reward callback).
  Future<bool> awardAdReward(String uid, int amount) async {
    final ref = _doc(uid);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final last = (data['lastAdRewardAt'] as Timestamp?)?.toDate();
      if (last != null && DateTime.now().difference(last) < adRewardCooldown) {
        return false;
      }
      tx.update(ref, {
        'points': ((data['points'] as num?)?.toInt() ?? 0) + amount,
        'lastAdRewardAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<void> selectAvatar(String uid, String avatarId) async {
    await _doc(uid).update({'selectedAvatar': avatarId});
  }

  Future<void> selectColor(String uid, String colorId) async {
    await _doc(uid).update({'selectedColor': colorId});
  }
}
