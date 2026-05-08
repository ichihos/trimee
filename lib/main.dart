import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'shared/providers/ad_provider.dart';

import 'shared/providers/guest_session_provider.dart';
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
    await adService.loadInterstitialAd();
  }

  // 起動時インタースティシャル広告表示
  if (!kIsWeb) {
    final adService = container.read(adServiceProvider);
    await adService.showInterstitialAdIfNeeded();
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const TrimeeApp()),
  );
}
