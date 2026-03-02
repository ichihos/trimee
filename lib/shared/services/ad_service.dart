import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trimee/core/constants/ad_constants.dart';

class AdService {
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;

  static const String _launchCountKey = 'app_launch_count';

  Future<void> init() async {
    // Webプラットフォームでは広告はサポートされていない
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
  }

  bool get isSupported => !kIsWeb;

  /// バナー広告を作成
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => debugPrint('Banner ad loaded'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
  }

  /// インタースティシャル広告をロード
  Future<void> loadInterstitialAd() async {
    if (kIsWeb) return;

    await InterstitialAd.load(
      adUnitId: AdConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('Interstitial ad loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('Interstitial ad dismissed');
              ad.dispose();
              _isInterstitialAdReady = false;
              // 次の広告をプリロード
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Interstitial ad failed to show: $error');
              ad.dispose();
              _isInterstitialAdReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  /// アプリ起動回数をチェックして、必要ならインタースティシャル広告を表示
  Future<void> showInterstitialAdIfNeeded() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final launchCount = (prefs.getInt(_launchCountKey) ?? 0) + 1;
    await prefs.setInt(_launchCountKey, launchCount);

    debugPrint('App launch count: $launchCount');

    // 2回目以降の起動でインタースティシャル広告を表示
    if (launchCount >= 2 && _isInterstitialAdReady) {
      await _interstitialAd?.show();
    }
  }

  /// リワード広告をロード
  Future<void> loadRewardedAd() async {
    if (kIsWeb) return;

    await RewardedAd.load(
      adUnitId: AdConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          debugPrint('Rewarded ad loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('Rewarded ad dismissed');
              ad.dispose();
              _isRewardedAdReady = false;
              // 次の広告をプリロード
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Rewarded ad failed to show: $error');
              ad.dispose();
              _isRewardedAdReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  /// リワード広告を表示
  Future<bool> showRewardedAd() async {
    if (kIsWeb || !_isRewardedAdReady || _rewardedAd == null) {
      return false;
    }

    bool rewarded = false;

    await _rewardedAd?.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        rewarded = true;
      },
    );

    return rewarded;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
