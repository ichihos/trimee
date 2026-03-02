/// アプリ内課金（IAP）関連の定数
///
/// RevenueCatを使用してiOS、Android、Web全てで統一的に課金を管理
class IAPConstants {
  // RevenueCat API Keys
  // ⚠️ 本番環境では環境変数から読み込むか、Firebase Remote Configで管理すること
  static const String revenueCatApiKeyIOS = 'YOUR_REVENUECAT_IOS_API_KEY';
  static const String revenueCatApiKeyAndroid = 'YOUR_REVENUECAT_ANDROID_API_KEY';
  static const String revenueCatApiKeyWeb = 'YOUR_REVENUECAT_WEB_API_KEY';

  // Product IDs
  // AI生成1回分の購入（消耗型アイテム）
  static const String aiGenerationProductId = 'ai_generation_120';

  // Entitlement ID (RevenueCat)
  // AI生成権の権限識別子
  static const String aiGenerationEntitlementId = 'ai_generation';

  // Offering ID (RevenueCat)
  // デフォルトのオファリング
  static const String defaultOfferingId = 'default';

  // 価格（表示用）
  static const int aiGenerationPriceYen = 120;
  static const String aiGenerationPriceDisplay = '¥120';

  // デバッグモード（サンドボックス環境）
  static const bool enableDebugLogs = true;
}
