import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdConstants {
  static const String appId = 'ca-app-pub-1198819922308744~1623067537';

  // iOS Ad Unit IDs
  static const String iosBannerAdUnitId =
      'ca-app-pub-1198819922308744/4836388389';
  static const String iosRewardedAdUnitId =
      'ca-app-pub-1198819922308744/8748004812';
  static const String iosInterstitialAdUnitId =
      'ca-app-pub-1198819922308744/3814842954';

  // Android Ad Unit IDs
  static const String androidBannerAdUnitId =
      'ca-app-pub-1198819922308744/1828372662';
  static const String androidRewardedAdUnitId =
      'ca-app-pub-1198819922308744/3931791824';
  static const String androidInterstitialAdUnitId =
      'ca-app-pub-1198819922308744/7148506747';

  // Platform-specific getters
  static String get bannerAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on web');
    return Platform.isIOS ? iosBannerAdUnitId : androidBannerAdUnitId;
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on web');
    return Platform.isIOS ? iosRewardedAdUnitId : androidRewardedAdUnitId;
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on web');
    return Platform.isIOS
        ? iosInterstitialAdUnitId
        : androidInterstitialAdUnitId;
  }
}
