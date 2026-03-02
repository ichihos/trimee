import 'package:shared_preferences/shared_preferences.dart';
import 'ad_service.dart';

/// リワード広告の視聴回数を管理し、AI生成権を付与するマネージャー
///
/// ビジネスロジック:
/// - 3本のリワード広告視聴 = AI生成1回分の権利
/// - 旅行ごとに進捗を管理（tripId単位）
/// - 3/3到達時に権利付与、カウンターリセット
class RewardedAdManager {
  final AdService _adService;

  /// SharedPreferencesキーのプレフィックス
  static const String _keyPrefix = 'reward_ad_progress_';

  RewardedAdManager(this._adService);

  /// 指定した旅行の現在の視聴進捗を取得（0〜3）
  Future<int> getWatchProgress(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyPrefix$tripId') ?? 0;
  }

  /// リワード広告を表示し、視聴進捗を更新する
  ///
  /// Returns:
  /// - `true`: 3本視聴完了でAI生成権を獲得した場合
  /// - `false`: まだ3本未満、または広告視聴失敗の場合
  ///
  /// 使用例:
  /// ```dart
  /// final earned = await rewardedAdManager.watchRewardAdForGeneration(tripId);
  /// if (earned) {
  ///   // AI生成を実行
  /// } else {
  ///   final progress = await rewardedAdManager.getWatchProgress(tripId);
  ///   // 「あと${3 - progress}本の広告視聴が必要です」と表示
  /// }
  /// ```
  Future<bool> watchRewardAdForGeneration(String tripId) async {
    // リワード広告を表示
    final watched = await _adService.showRewardedAd();

    if (!watched) {
      // 広告視聴失敗（ユーザーがスキップ、または広告ロード失敗）
      return false;
    }

    // 視聴成功: 進捗をインクリメント
    final prefs = await SharedPreferences.getInstance();
    final currentProgress = await getWatchProgress(tripId);
    final newProgress = currentProgress + 1;

    if (newProgress >= 3) {
      // 3本視聴完了 → カウンターをリセットして権利付与
      await prefs.setInt('$_keyPrefix$tripId', 0);
      return true; // AI生成権獲得
    } else {
      // まだ3本未満 → 進捗を保存
      await prefs.setInt('$_keyPrefix$tripId', newProgress);
      return false;
    }
  }

  /// 指定した旅行の視聴進捗をリセット（デバッグ用、または手動リセット時）
  Future<void> resetProgress(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$tripId');
  }

  /// 残り必要な視聴回数を取得（3 - 現在の進捗）
  Future<int> getRemainingWatchCount(String tripId) async {
    final progress = await getWatchProgress(tripId);
    return 3 - progress;
  }

  /// 視聴進捗の状態を人間が読める形式で取得（例: "1/3本視聴済み"）
  Future<String> getProgressText(String tripId) async {
    final progress = await getWatchProgress(tripId);
    return '$progress/3本視聴済み';
  }
}
