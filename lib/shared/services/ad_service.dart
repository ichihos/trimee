import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:trimee/core/constants/ad_constants.dart';

class AdService {
  Future<void> init() async {
    // Webプラットフォームでは広告はサポートされていない
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
  }

  bool get isSupported => !kIsWeb;

  String get appOpenAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on web');
    if (Platform.isAndroid || Platform.isIOS) {
      return AdConstants.appOpenAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  String get rewardedAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on web');
    if (Platform.isAndroid || Platform.isIOS) {
      return AdConstants.rewardedAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  String get bannerAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on web');
    if (Platform.isAndroid || Platform.isIOS) {
      return AdConstants.bannerAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }
}
