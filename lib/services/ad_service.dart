import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps AdMob banner ads. Ships with Google's official *test* ad unit
/// ID so the game shows real (test) ads immediately in development —
/// swap [bannerAdUnitId] for your own once you've created an AdMob
/// account: https://support.google.com/admob/answer/9905175
class AdService {
  AdService._();

  /// Google's public test banner unit — safe to ship during development,
  /// never earns real revenue. Replace with your production ad unit ID.
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static Future<void> initialize() => MobileAds.instance.initialize();
}
