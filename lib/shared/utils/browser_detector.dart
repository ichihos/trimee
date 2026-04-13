import 'package:flutter/foundation.dart';
import 'browser_detector_stub.dart'
    if (dart.library.html) 'browser_detector_web.dart';

/// ブラウザ検出ユーティリティ
class BrowserDetector {
  /// 非正規ブラウザ（LINEアプリ内ブラウザなど）を検出
  static bool isInAppBrowser() {
    if (!kIsWeb) return false;

    try {
      final userAgent = getUserAgent();
      if (userAgent == null || userAgent.isEmpty) return false;

      // LINEアプリ内ブラウザ
      if (userAgent.contains('Line/')) return true;

      // Facebookアプリ内ブラウザ
      if (userAgent.contains('FBAN') || userAgent.contains('FBAV')) return true;

      // Twitterアプリ内ブラウザ
      if (userAgent.contains('Twitter')) return true;

      // Instagramアプリ内ブラウザ
      if (userAgent.contains('Instagram')) return true;

      return false;
    } catch (e) {
      debugPrint('Error detecting in-app browser: $e');
      return false;
    }
  }

  /// ブラウザ名を取得
  static String getBrowserName() {
    if (!kIsWeb) return 'Unknown';

    try {
      final userAgent = getUserAgent();
      if (userAgent == null || userAgent.isEmpty) return 'Unknown';

      if (userAgent.contains('Line/')) return 'LINE';
      if (userAgent.contains('FBAN') || userAgent.contains('FBAV')) {
        return 'Facebook';
      }
      if (userAgent.contains('Twitter')) return 'Twitter';
      if (userAgent.contains('Instagram')) return 'Instagram';

      return 'Unknown';
    } catch (e) {
      debugPrint('Error getting browser name: $e');
      return 'Unknown';
    }
  }

  /// 正規ブラウザで開くためのURL
  static String getExternalBrowserUrl(String currentUrl) {
    // そのまま同じURLを返す（ユーザーがコピーして正規ブラウザで開く）
    return currentUrl;
  }
}
