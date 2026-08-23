import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps AdMob banner ads, using the real production ad unit (the
/// matching app ID lives in android/app/src/main/AndroidManifest.xml).
class AdService {
  AdService._();

  static const String bannerAdUnitId = 'ca-app-pub-1873691727255458/7432784335';

  static Future<void> initialize() => MobileAds.instance.initialize();
}
