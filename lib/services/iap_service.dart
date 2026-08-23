import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/shop_items.dart';
import 'profile_service.dart';

/// Wraps the Play Store billing flow for buying Étincelles with real
/// money. Until the app is published with these exact product IDs
/// configured in the Play Console (Monetize > Products > In-app
/// products), [isAvailable] stays false and nothing can be bought — that
/// is expected while developing, not a bug.
///
/// There's no backend here to verify a purchase receipt server-side, so
/// this trusts whatever the Play Store billing client reports — a
/// reasonable trade-off for a small non-commercial class app, but worth
/// knowing if this ever needs hardening against real fraud.
class IapService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final ProfileService _profileService = ProfileService();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  String? _uid;

  Future<bool> get isAvailable => _iap.isAvailable();

  Future<List<ProductDetails>> loadProducts() async {
    final ids = pointsPacks.map((p) => p.productId).toSet();
    final response = await _iap.queryProductDetails(ids);
    return response.productDetails;
  }

  /// Starts listening for purchase updates and crediting the given
  /// player's profile when one completes. Call once, e.g. when the shop
  /// screen opens.
  void start(String uid) {
    _uid = uid;
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final uid = _uid;
        if (uid != null) {
          for (final pack in pointsPacks) {
            if (pack.productId == purchase.productID) {
              await _profileService.awardPoints(uid, pack.points);
              break;
            }
          }
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }
}
