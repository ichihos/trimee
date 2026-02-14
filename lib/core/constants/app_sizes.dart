/// trimeeのサイズ定数
/// 仕様書のUIトーンに基づいたサイズ設定
class AppSizes {
  AppSizes._();

  // パディング・マージン
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  // 角丸（カード: 大きめ 16px）
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  // アイコン（線画、ストローク2px）
  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;
  static const double iconStrokeWidth = 2.0;

  // ボタン
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonMinWidth = 120.0;

  // カード
  static const double cardMinHeight = 80.0;
  static const double cardElevation = 2.0;

  // アバター
  static const double avatarS = 24.0;
  static const double avatarM = 32.0;
  static const double avatarL = 48.0;

  // 入力フィールド
  static const double inputHeight = 48.0;
  static const double inputBorderWidth = 1.0;

  // アニメーション（ふわっと出る）
  static const int animationDurationFast = 150;
  static const int animationDurationNormal = 300;
  static const int animationDurationSlow = 500;

  // 最大幅
  static const double maxContentWidth = 600.0;
  static const double maxCardWidth = 400.0;
}
