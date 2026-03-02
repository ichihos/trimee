import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'shared/providers/ad_provider.dart';
import 'shared/providers/firebase_providers.dart';
import 'shared/providers/guest_session_provider.dart';
import 'shared/providers/iap_provider.dart';
import 'shared/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase初期化
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // AdMob初期化
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  // SharedPreferences初期化
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // ゲストセッション復元（Webリロード対策）
  container.read(guestSessionProvider.notifier).restoreSession(prefs);

  // AdMob: 広告をプリロード
  if (!kIsWeb) {
    final adService = container.read(adServiceProvider);
    await adService.init();
    await adService.loadInterstitialAd(); // 初回AI生成用にプリロード
    await adService.loadRewardedAd(); // 2回目以降のAI生成用にプリロード
  }

  // RevenueCat (IAP) 初期化
  try {
    final iapService = container.read(iapServiceProvider);
    final userId = container.read(currentUserIdProvider) ?? '';
    await iapService.initialize(userId);
  } catch (e) {
    print('[Main] IAP initialization failed: $e');
    // IAP初期化失敗は致命的ではないため、アプリは起動を続ける
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const TrimeeApp()),
  );
}
