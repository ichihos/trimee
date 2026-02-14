import 'package:flutter/material.dart';

/// trimeeのカラーパレット
/// 仕様書に基づいた「余白のある旅支度」をテーマにしたカラー
class AppColors {
  AppColors._();

  /// ダークモードかどうか（ルートウィジェットから設定される）
  static bool _isDark = false;

  /// ダークモードフラグを更新
  static void updateBrightness(bool isDark) {
    _isDark = isDark;
  }

  // ── ブライトネスに応じて変わるカラー ──

  /// 背景色
  static Color get background =>
      _isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAF9F7);

  /// 墨色（薄め） - テキスト
  static Color get textPrimary =>
      _isDark ? const Color(0xFFE8E5E0) : const Color(0xFF2D2D2D);

  /// カード背景
  static Color get cardBackground =>
      _isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F0E8);

  /// テキストセカンダリ
  static Color get textSecondary =>
      _isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B6B6B);

  /// ボーダー・ディバイダー
  static Color get border =>
      _isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE5E0D8);

  /// シャドウ
  static Color get shadow =>
      _isDark ? const Color(0x33000000) : const Color(0x0D000000);

  /// オーバーレイ
  static Color get overlay =>
      _isDark ? const Color(0x66000000) : const Color(0x33000000);

  // ── テーマに依存しない固定カラー ──

  /// テラコッタ - アクセント（CTA、通知）
  static const Color accent = Color(0xFFC4765B);

  /// セージグリーン - サブアクセント
  static const Color subAccent = Color(0xFF8BA888);

  /// エラー
  static const Color error = Color(0xFFD94D4D);

  /// サクセス
  static const Color success = Color(0xFF4CAF50);

  // リアクション用カラー
  /// いいね（👍）
  static const Color reactionUp = Color(0xFF8BA888);

  /// まあまあ（😐）
  static const Color reactionNeutral = Color(0xFFB0A090);

  /// パス（👎）
  static const Color reactionDown = Color(0xFFC4765B);
}
