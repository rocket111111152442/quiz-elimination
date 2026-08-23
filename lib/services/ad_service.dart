import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps AdMob banner and rewarded ads, using the real production ad
/// units (the matching app ID lives in
/// android/app/src/main/AndroidManifest.xml).
class AdService {
  AdService._();

  static const String bannerAdUnitId = 'ca-app-pub-1873691727255458/7432784335';

  // TODO: Google's official *test* rewarded ad unit — replace with the
  // real one once created in the AdMob console (Apps > ton appli > Unités
  // publicitaires > Ajouter une unité > Récompensée), the same way the
  // banner ID above was swapped for the real one.
  static const String rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static Future<void> initialize() => MobileAds.instance.initialize();

  /// Loads and shows a rewarded ad. Returns true only if the viewer
  /// watched it through to the point AdMob grants the reward — false on
  /// any failure (no ad available, no network, closed early).
  static Future<bool> showRewardedAd() {
    final completer = Completer<bool>();
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              if (!completer.isCompleted) completer.complete(true);
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );
    return completer.future;
  }
}
