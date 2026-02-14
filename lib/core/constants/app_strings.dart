/// trimeeの文字列定数
/// 仕様書のコピートーンに基づいた文言
class AppStrings {
  AppStrings._();

  // アプリ名
  static const String appName = 'trimee';
  static const String appTagline = '計画から、旅ははじまる';

  // 一般
  static const String loading = '読み込み中...';
  static const String error = 'エラーが発生しました';
  static const String retry = '再試行';
  static const String cancel = 'キャンセル';
  static const String save = '保存';
  static const String delete = '削除';
  static const String edit = '編集';
  static const String done = '完了';
  static const String next = '次へ';
  static const String back = '戻る';

  // 認証
  static const String signIn = 'サインイン';
  static const String signUp = 'アカウント作成';
  static const String signOut = 'サインアウト';
  static const String signInWithGoogle = 'Googleでサインイン';
  static const String signInWithEmail = 'メールでサインイン';
  static const String email = 'メールアドレス';
  static const String password = 'パスワード';
  static const String welcomeMessage = '旅の計画を始める';

  // ホーム
  static const String home = 'ホーム';
  static const String noTrips = '旅の計画がありません';
  static const String createFirstTrip = '最初の旅を計画する';
  static const String pastTrips = '確定済みプラン';

  // 旅行
  static const String newTrip = '新しい旅行';
  static const String tripTitle = '旅行タイトル';
  static const String tripTitleHint = '例: 沖縄旅行';
  static const String tripDate = '日程';
  static const String tripDateUndecided = '未定';
  static const String tripMembers = 'メンバー';
  static const String inviteMembers = '招待する';
  static const String votePending = '投票待ち';
  static const String planConfirmed = 'プラン確定済み';
  static const String viewCards = 'カードを見る';
  static const String viewPlan = 'プランを見る';

  // カード
  static const String cards = 'カード';
  static const String addCard = 'カードを追加';
  static const String cardPlaceholder = '行きたい場所やりたいこと';
  static const String everyonesWishlist = 'メンバーの希望';
  static const String emptyCards = 'カードがありません';
  static const String anonymous = '匿名';

  // リアクション
  static const String reactionUp = 'いいね';
  static const String reactionNeutral = 'まあまあ';
  static const String reactionDown = 'パス';

  // プラン
  static const String plan = 'プラン';
  static const String generatePlan = 'AIでプランを生成';
  static const String generatingPlan = 'プラン生成中...';
  static const String activePlan = 'アクティブプラン';
  static const String relaxedPlan = 'ゆったりプラン';
  static const String budgetPlan = 'コスパプラン';
  static const String includedCards = '採用カード';
  static const String excludedCards = '不採用カード';
  static const String restoreCard = 'カードを復活';
  static const String detailMode = '詳細モード';

  // 投票
  static const String voting = '投票中';
  static const String voteComplete = '全員投票完了';
  static const String voteCompleteMessage = '投票が完了しました';

  // 確定
  static const String confirmPlan = 'プランを確定';
  static const String planConfirmedMessage = 'プランが確定しました';

  // 共有
  static const String share = '共有';
  static const String copyLink = 'リンクをコピー';
  static const String linkCopied = 'リンクをコピーしました';

  // エラーメッセージ
  static const String networkError = 'ネットワークエラーが発生しました';
  static const String authError = '認証エラーが発生しました';
  static const String unknownError = '予期しないエラーが発生しました';
}
