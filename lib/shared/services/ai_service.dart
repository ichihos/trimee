import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_model.dart';
import '../models/plan_model.dart';
import '../models/user_profile_model.dart';

/// AIサービスプロバイダー
final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

/// AIサービス
/// 仕様書に基づき、プラン生成にはPro、代弁AIにはFlashを使用
class AIService {
  // Gemini Flash（低コスト・高速）- 代弁AI、サジェスト用
  // 利用可能なモデル: gemini-3-flash, gemini-2.0-flash-exp, gemini-1.5-flash
  GenerativeModel get _flashModel => FirebaseAI.vertexAI(
    location: 'global',
  ).generativeModel(model: 'gemini-3-flash-preview');

  // Gemini Pro（高品質）- プラン生成用
  // 利用可能なモデル: gemini-3-pro, gemini-2.0-pro-exp, gemini-1.5-pro
  GenerativeModel get _proModel => FirebaseAI.vertexAI(
    location: 'global',
  ).generativeModel(model: 'gemini-3-pro-preview');

  /// プラン生成（複数パターン）- ストリーミング版
  /// 仕様書: アクティブ重視、のんびり、コスパ重視の3パターン
  /// プランが生成されるたびにStreamで返す
  Stream<GeneratedPlan> generatePlansStream({
    required String tripTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<CardModel> cards,
    required List<UserProfileModel> memberProfiles,
    required Map<String, String> userIdToName,
    Map<String, String>? memberDepartures,
  }) async* {
    final prompt = _buildPlanPrompt(
      tripTitle: tripTitle,
      startDate: startDate,
      endDate: endDate,
      cards: cards,
      memberProfiles: memberProfiles,
      userIdToName: userIdToName,
      memberDepartures: memberDepartures,
    );

    try {
      final stream = _proModel.generateContentStream([Content.text(prompt)]);
      final buffer = StringBuffer();
      final emittedTypes = <String>{};

      await for (final response in stream) {
        final text = response.text ?? '';
        buffer.write(text);

        // バッファから完成したプランを抽出して順次yield
        final accumulated = buffer.toString();
        final plans = _extractPlansFromPartialJson(accumulated);

        for (final plan in plans) {
          if (!emittedTypes.contains(plan.type)) {
            emittedTypes.add(plan.type);
            yield plan;
          }
        }
      }

      // 最終的に残っているプランがあれば出力
      final finalText = buffer.toString();
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(finalText);
      if (jsonMatch != null) {
        try {
          final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          final plansJson = json['plans'] as List<dynamic>? ?? [];
          for (final p in plansJson) {
            final plan = GeneratedPlan.fromJson(p);
            if (!emittedTypes.contains(plan.type)) {
              emittedTypes.add(plan.type);
              yield plan;
            }
          }
        } catch (_) {
          // 最終パースに失敗しても、途中で出力したプランがあればOK
        }
      }
    } catch (e) {
      debugPrint('AI Plan Generation Stream Error: $e');
      rethrow;
    }
  }

  /// プラン生成（リアルタイムアイテム表示版）
  /// 生のストリーミングテキストを返し、UI側でリアルタイム表示
  Stream<GenerationEvent> generateWithRealTimeStream({
    required String tripTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<CardModel> cards,
    required List<UserProfileModel> memberProfiles,
    required Map<String, String> userIdToName,
    Map<String, String>? memberDepartures,
  }) async* {
    final prompt = _buildPlanPrompt(
      tripTitle: tripTitle,
      startDate: startDate,
      endDate: endDate,
      cards: cards,
      memberProfiles: memberProfiles,
      userIdToName: userIdToName,
      memberDepartures: memberDepartures,
    );

    yield const GenerationEvent.started();

    try {
      final stream = _proModel.generateContentStream([Content.text(prompt)]);
      final buffer = StringBuffer();
      final emittedItems = <String>{}; // "planType:day:time:location"
      final emittedPlanTitles = <String>{};

      await for (final response in stream) {
        final text = response.text ?? '';
        buffer.write(text);

        // 生テキストを送信（UIでストリーミング表示用）
        if (text.isNotEmpty) {
          yield GenerationEvent.textChunk(text);
        }

        // バッファからアイテムを抽出
        final accumulated = buffer.toString();

        // プランタイトルを抽出
        final titleMatches = RegExp(
          r'"type"\s*:\s*"(plan\d+)"\s*,\s*"title"\s*:\s*"([^"]*)"',
        ).allMatches(accumulated);
        for (final match in titleMatches) {
          final planType = match.group(1)!;
          final title = match.group(2)!;
          final key = '$planType:$title';
          if (!emittedPlanTitles.contains(key)) {
            emittedPlanTitles.add(key);
            yield GenerationEvent.planStarted(planType: planType, title: title);
          }
        }

        // 個別アイテムを抽出
        final itemPattern = RegExp(
          r'\{\s*"day"\s*:\s*(\d+)\s*,\s*"time"\s*:\s*"([^"]*)"\s*,\s*"location"\s*:\s*"([^"]*)"\s*,\s*"latitude"\s*:\s*([^,]*)\s*,\s*"longitude"\s*:\s*([^,]*)\s*,\s*"duration"\s*:\s*(\d+)\s*,\s*"notes"\s*:\s*"([^"]*)"',
        );

        for (final match in itemPattern.allMatches(accumulated)) {
          final day = int.parse(match.group(1)!);
          final time = match.group(2)!;
          final location = match.group(3)!;
          final latStr = match.group(4)!.trim();
          final lngStr = match.group(5)!.trim();
          final duration = int.parse(match.group(6)!);
          final notes = match.group(7);

          final itemKey = '$day:$time:$location';
          if (!emittedItems.contains(itemKey)) {
            emittedItems.add(itemKey);
            yield GenerationEvent.itemGenerated(
              item: PlanItemData(
                day: day,
                time: time,
                location: location,
                duration: duration,
                notes: notes,
                latitude: latStr != 'null' ? double.tryParse(latStr) : null,
                longitude: lngStr != 'null' ? double.tryParse(lngStr) : null,
              ),
            );
          }
        }

        // 完成したプランを抽出してイベント発行
        // 各プランオブジェクトを個別に抽出
        final planPattern = RegExp(
          r'\{\s*"type"\s*:\s*"plan\d+"\s*,\s*"title"\s*:\s*"[^"]*"\s*,\s*"description"\s*:\s*"[^"]*"\s*,\s*"items"\s*:\s*\[[\s\S]*?\]\s*,\s*"includedCards"\s*:\s*\[[^\]]*\]\s*,\s*"excludedCards"\s*:\s*\[[^\]]*\]\s*\}',
        );

        for (final match in planPattern.allMatches(accumulated)) {
          final planJsonStr = match.group(0)!;
          // タイトルをキーにして重複チェック（簡易的）
          // 厳密にはプラン全体の内容で判定すべきだが、タイトルとタイプが含まれていれば特定可能
          final titleMatch = RegExp(
            r'"title"\s*:\s*"([^"]*)"',
          ).firstMatch(planJsonStr);
          final typeMatch = RegExp(
            r'"type"\s*:\s*"(plan\d+)"',
          ).firstMatch(planJsonStr);

          if (titleMatch != null && typeMatch != null) {
            final planKey =
                '${typeMatch.group(1)}:${titleMatch.group(1)}:completed';
            if (!emittedPlanTitles.contains(planKey)) {
              try {
                final planJson =
                    jsonDecode(planJsonStr) as Map<String, dynamic>;
                final plan = GeneratedPlan.fromJson(planJson);
                emittedPlanTitles.add(planKey);
                yield GenerationEvent.planCompleted(plan: plan);
              } catch (_) {
                // パース中のエラーは無視（まだ不完全な可能性もあるが、正規表現でマッチしているので基本は大丈夫）
              }
            }
          }
        }
      }

      // 最終プランを抽出して完了イベント
      final finalText = buffer.toString();
      final plans = <GeneratedPlan>[];
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(finalText);
      if (jsonMatch != null) {
        try {
          final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          final plansJson = json['plans'] as List<dynamic>? ?? [];
          for (final p in plansJson) {
            plans.add(GeneratedPlan.fromJson(p));
          }
        } catch (_) {}
      }

      yield GenerationEvent.completed(plans: plans);
    } catch (e) {
      debugPrint('AI Real-time Generation Error: $e');
      yield GenerationEvent.error(message: e.toString());
    }
  }

  /// 部分的なJSONから完成したプランを抽出
  List<GeneratedPlan> _extractPlansFromPartialJson(String text) {
    final plans = <GeneratedPlan>[];

    // 各プランオブジェクトを個別に抽出
    final planPattern = RegExp(
      r'\{\s*"type"\s*:\s*"plan\d+"\s*,\s*"title"\s*:\s*"[^"]*"\s*,\s*"description"\s*:\s*"[^"]*"\s*,\s*"items"\s*:\s*\[[\s\S]*?\]\s*,\s*"includedCards"\s*:\s*\[[^\]]*\]\s*,\s*"excludedCards"\s*:\s*\[[^\]]*\]\s*\}',
    );

    for (final match in planPattern.allMatches(text)) {
      try {
        final planJson = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        plans.add(GeneratedPlan.fromJson(planJson));
      } catch (_) {
        // パースに失敗したプランはスキップ
      }
    }

    return plans;
  }

  /// プラン生成（複数パターン）- 従来版（互換性のため残す）
  /// 仕様書: アクティブ重視、のんびり、コスパ重視の3パターン
  Future<List<GeneratedPlan>> generatePlans({
    required String tripTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<CardModel> cards,
    required List<UserProfileModel> memberProfiles,
    required Map<String, String> userIdToName,
  }) async {
    final plans = <GeneratedPlan>[];
    await for (final plan in generatePlansStream(
      tripTitle: tripTitle,
      startDate: startDate,
      endDate: endDate,
      cards: cards,
      memberProfiles: memberProfiles,
      userIdToName: userIdToName,
    )) {
      plans.add(plan);
    }
    return plans;
  }

  /// プロンプト生成（共通化）
  String _buildPlanPrompt({
    required String tripTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<CardModel> cards,
    required List<UserProfileModel> memberProfiles,
    required Map<String, String> userIdToName,
    Map<String, String>? memberDepartures,
  }) {
    // カードをタイプ別に分類
    final confirmedCards =
        cards.where((c) => c.cardType == CardType.confirmed).toList();
    final placeCards =
        cards.where((c) => c.cardType == CardType.place).toList();
    final activityCards =
        cards.where((c) => c.cardType == CardType.activity).toList();
    final atmosphereCards =
        cards.where((c) => c.cardType == CardType.atmosphere).toList();
    final budgetCards =
        cards.where((c) => c.cardType == CardType.budget).toList();
    final avoidPlaceCards =
        cards.where((c) => c.cardType == CardType.avoidPlace).toList();
    final avoidActivityCards =
        cards.where((c) => c.cardType == CardType.avoidActivity).toList();

    // カード情報を整形する関数
    String formatCard(CardModel c) {
      final creatorName = userIdToName[c.createdBy] ?? '匿名';
      final upVoters =
          c.reactions.entries
              .where((e) => e.value == ReactionType.up)
              .map((e) => userIdToName[e.key] ?? '匿名')
              .toList();
      final downVoters =
          c.reactions.entries
              .where((e) => e.value == ReactionType.down)
              .map((e) => userIdToName[e.key] ?? '匿名')
              .toList();

      final desc =
          c.description != null && c.description!.isNotEmpty
              ? '（${c.description}）'
              : '';
      final upVotersList =
          upVoters.isNotEmpty ? '、いいね: ${upVoters.join(', ')}' : '';
      final downVotersList =
          downVoters.isNotEmpty ? '、パス: ${downVoters.join(', ')}' : '';
      final creator = c.anonymous ? '匿名' : creatorName;

      return '- ${c.title}$desc\n  投稿者: $creator、評価: いいね${c.upCount}件/まあまあ${c.neutralCount}件/パス${c.downCount}件$upVotersList$downVotersList';
    }

    // メンバー情報
    final membersInfo =
        memberProfiles.map((p) => p.toPromptDescription()).toList();

    // 日程情報を計算
    String dateInfo;
    int totalDays = 1;
    if (startDate != null && endDate != null) {
      totalDays = endDate.difference(startDate).inDays + 1;
      dateInfo =
          '${startDate.month}/${startDate.day}〜${endDate.month}/${endDate.day}（$totalDays日間）';
    } else {
      dateInfo = '日程未定（1日としてプラン作成）';
    }

    // 各カテゴリのカード情報を整形
    final confirmedCardsText =
        confirmedCards.isNotEmpty ? confirmedCards.map(formatCard).join('\n') : 'なし';
    final placeCardsText =
        placeCards.isNotEmpty ? placeCards.map(formatCard).join('\n') : 'なし';
    final activityCardsText =
        activityCards.isNotEmpty
            ? activityCards.map(formatCard).join('\n')
            : 'なし';
    final atmosphereCardsText =
        atmosphereCards.isNotEmpty
            ? atmosphereCards.map(formatCard).join('\n')
            : 'なし';
    final budgetCardsText =
        budgetCards.isNotEmpty ? budgetCards.map(formatCard).join('\n') : 'なし';
    final avoidPlaceCardsText =
        avoidPlaceCards.isNotEmpty
            ? avoidPlaceCards.map(formatCard).join('\n')
            : 'なし';
    final avoidActivityCardsText =
        avoidActivityCards.isNotEmpty
            ? avoidActivityCards.map(formatCard).join('\n')
            : 'なし';

    // 全カードのタイトルリストを作成（採用/除外の参照用）
    final allCardTitles =
        cards.where((c) => c.cardType.isPositive).map((c) => c.title).toList();

    final prompt = '''
あなたは旅行プランナーAIです。以下の情報から3つの異なるコンセプトの旅行プランを提案してください。

【旅行情報】
- タイトル: $tripTitle
- 日程: $dateInfo

【参加メンバー】
${membersInfo.isNotEmpty ? membersInfo.map((m) => '- $m').join('\n') : '- 情報なし'}

${memberDepartures != null && memberDepartures.isNotEmpty ? '''【メンバーの出発地点】
${memberDepartures.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

※ 上記の出発地点を考慮して、集合場所の提案や交通費の最適化を行ってください。
''' : ''}

【決まっていること（最優先で反映）】
$confirmedCardsText

【行きたい場所】
$placeCardsText

【やりたいこと】
$activityCardsText

【旅の雰囲気・希望】
$atmosphereCardsText

【予算・お金の希望】
$budgetCardsText

【避けたい場所】
$avoidPlaceCardsText

【避けたいこと】
$avoidActivityCardsText

【登録されているカード一覧】（採用/除外の参照用）
${allCardTitles.join('、')}

【出力形式】
以下のJSON形式で3つのプランを出力してください。タイトルは創造的で魅力的なものにしてください:
```json
{
  "plans": [
    {
      "type": "plan1",
      "title": "創造的で魅力的なプランタイトル",
      "description": "このプランの特徴や魅力を1文で説明",
      "items": [
        {"day": 1, "time": "09:00", "location": "集合場所", "latitude": 35.6812, "longitude": 139.7671, "duration": 30, "notes": "出発前の準備", "isPlaceholder": false},
        {"day": 1, "time": "10:00", "location": "具体的な場所名", "latitude": 35.6812, "longitude": 139.7671, "duration": 60, "notes": "過ごし方のポイント", "isPlaceholder": false},
        {"day": 1, "time": "12:00", "location": "※ランチ（未定）", "latitude": null, "longitude": null, "duration": 90, "notes": "お店を選んでください", "isPlaceholder": true}
      ],
      "includedCards": ["プランに採用したカードのタイトル"],
      "excludedCards": ["プランに含めなかったカードのタイトル"]
    },
    {
      "type": "plan2",
      "title": "異なるコンセプトの魅力的なタイトル",
      "description": "...",
      "items": [...],
      "includedCards": [...],
      "excludedCards": [...]
    },
    {
      "type": "plan3",
      "title": "また違った切り口のタイトル",
      "description": "...",
      "items": [...],
      "includedCards": [...],
      "excludedCards": [...]
    }
  ]
}
```

【重要な指示】

【スケジュール生成のルール】
- **全${totalDays}日分のフルスケジュールを必ず生成すること**（day: 1 から day: $totalDays まで）
- **1日目の最初のアイテムは必ず「集合」にすること**（location: "集合場所" または "東京駅" などの具体的な場所）
- 各日のタイムスケジュール：
  - 1日目: 集合〜21:00（集合、移動、午前・午後・夜のアクティビティ）
  - 中日: 09:00～21:00（終日フルに活動）
  - 最終日: 09:00～18:00（帰路を考慮）
- 各日最低6つ以上のアイテムを含める（食事3回＋アクティビティ）

【プレースホルダーの使い方】
- ユーザーが後で埋める枚を確保するために`isPlaceholder: true`を使用
- プレースホルダーの例:
  - 「※ランチ（未定）」「※ディナー（未定）」（食事の場合）
  - 「※自由時間」（フリータイム）
  - 「※周辺散策」（散策枠）
  - 「※お土産購入」（買い物枠）
- プレースホルダーはlatitude/longitudeはnull
- カードに具体的な希望がない時間帯は積極的にプレースホルダーを使用

【その他のルール】
- **「決まっていること」は全プランに必ず反映する**（目的地、宿泊先、交通手段など確定済みの情報は変更不可）
- 「決まっていること」に目的地や地域が含まれている場合、その地域を中心にプランを構成する
- タイトルは「○○プラン」のような形式的なものではなく、旅の魅力が伝わる創造的なものにする
- 3つのプランはそれぞれ異なるコンセプト（例：アクティブ派向け、のんびり派向け、グルメ重視など）
- includedCards/excludedCardsは【登録されているカード一覧】から正確にコピーする
- 全てのカードはincludedCardsかexcludedCardsのいずれかに含める
- メンバーの年代・性別・旅行スタイルを考慮してプランを最適化
- いいね数が多いものを優先採用、パス数が多いものは除外検討
- 「避けたい場所/こと」は絶対にプランに含めない
- 移動時間を考慮して現実的なスケジュールに
- 各スポットのlatitude/longitudeは、その場所の実際の座標を正確に指定する（地図表示に使用）
''';

    return prompt;
  }

  /// 不在者代弁AI
  /// 仕様書: メンバーの希望メモを元に、議論中に代弁
  Future<String> speakForAbsentMember({
    required String memberName,
    required String memberPreferences,
    required String currentTopic,
    required List<String> recentMessages,
  }) async {
    final prompt = '''
あなたは「$memberName」の代弁AIです。$memberNameの希望を代弁してください。

【$memberNameの希望メモ】
$memberPreferences

【現在の話題】
$currentTopic

【最近のメッセージ】
${recentMessages.join('\n')}

【指示】
- $memberNameの希望に基づいて、簡潔に（1-2文で）意見を述べてください
- 「$memberNameは〜って言ってたよ」のような口調で
- 押し付けがましくなく、さりげなく伝える
''';

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);
      return response.text ?? '$memberNameの希望を確認中...';
    } catch (e) {
      return '$memberNameの希望を確認中...';
    }
  }

  /// カード分析（Flash使用・高速）
  /// プラン生成前にカードの内容を分析してインサイトを返す
  Future<CardAnalysis> analyzeCards({
    required List<CardModel> cards,
    required List<UserProfileModel> memberProfiles,
    required Map<String, String> userIdToName,
  }) async {
    final cardSummary = cards.map((c) {
      final creator = c.anonymous ? '匿名' : (userIdToName[c.createdBy] ?? '匿名');
      return '${c.cardType.emoji} ${c.title}（$creator、いいね${c.upCount}）';
    }).join('\n');

    final membersText = memberProfiles.map((p) => p.toPromptDescription()).join(', ');

    final prompt = '''
以下の旅行カード一覧を分析して、グループの傾向をJSON形式で返してください。

【メンバー】
$membersText

【カード一覧】
$cardSummary

【出力形式】
```json
{
  "keywords": ["グループの希望を表すキーワード3〜5個"],
  "topSpot": "最も人気のあるスポット/アクティビティ名",
  "groupStyle": "このグループの旅行スタイルを一言で（例: のんびりグルメ旅、アクティブ観光派）",
  "funFact": "カードから読み取れる面白いインサイト1文（例: 全員が海を希望しています！）",
  "memberHighlights": [
    {"name": "名前", "want": "その人の一番の希望"}
  ]
}
```
短く簡潔に返してください。
''';

    try {
      final response = await _flashModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return CardAnalysis.fromJson(json);
      }
    } catch (e) {
      debugPrint('Card analysis error: $e');
    }
    // fallback
    return CardAnalysis(
      keywords: cards.take(3).map((c) => c.title).toList(),
      topSpot: cards.isNotEmpty ? cards.first.title : '',
      groupStyle: '楽しい旅行',
      funFact: '${cards.length}枚のカードが集まりました',
      memberHighlights: [],
    );
  }

  /// カード追加サジェスト
  /// 仕様書: カード追加ごとに「近くにこれも」と提案
  Future<List<String>> suggestRelatedPlaces({
    required String placeName,
    required String? region,
  }) async {
    final regionText = region != null ? '（$region）' : '';
    final prompt = '''
「$placeName」$regionTextに行くなら、近くでおすすめの場所を3つ教えてください。

【出力形式】
場所名のみ、1行1つで出力（説明不要）:
場所1
場所2
場所3
''';

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);
      final text = response.text ?? '';
      return text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// プラン編集サポート（Flash使用）
  /// ユーザーのリクエストに応じてプランを調整
  Future<PlanEditSuggestion> suggestPlanEdit({
    required String userRequest,
    required String currentPlanTitle,
    required String currentPlanDescription,
    required List<PlanItem> currentItems,
  }) async {
    // 現在のスケジュールを文字列に変換
    final scheduleText = currentItems
        .map((item) {
          final notes = item.notes != null ? '（${item.notes}）' : '';
          return '${item.day}日目 ${item.time} - ${item.location}$notes（${item.durationMinutes}分）';
        })
        .join('\n');

    final prompt = '''
あなたは旅行プランの編集アシスタントです。ユーザーのリクエストに応じてプランの改善提案をしてください。

【現在のプラン】
タイトル: $currentPlanTitle
説明: $currentPlanDescription

【現在のスケジュール】
$scheduleText

【ユーザーのリクエスト】
$userRequest

【出力形式】
以下のJSON形式で回答してください:
```json
{
  "suggestion": "提案内容を簡潔に説明（2-3文）",
  "updatedItems": [
    {"day": 1, "time": "10:00", "location": "場所名", "duration": 60, "notes": "メモ"}
  ],
  "tips": "追加のアドバイス（1文）"
}
```

【重要な指示】
- updatedItemsには必ず【完全なスケジュール】を含めること
- 追加の場合：既存のアイテムすべて ＋ 新しいアイテム
- 変更の場合：変更後のアイテムすべて（変更していないものも含む）
- 削除の場合：削除後の残りのアイテムすべて
- 既存のアイテムを削除してはいけない（削除がリクエストされた場合を除く）
- 移動時間を考慮した現実的なスケジュールに
- 時間順にソートして出力
- 「tips」には旅行を楽しむためのワンポイントアドバイスを
''';

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);
      final text = response.text ?? '';

      // JSONを抽出してパース
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return PlanEditSuggestion.fromJson(json);
      }

      return PlanEditSuggestion(
        suggestion: text,
        updatedItems: null,
        tips: null,
      );
    } catch (e) {
      debugPrint('AI Plan Edit Error: $e');
      return PlanEditSuggestion(
        suggestion: 'すみません、提案を生成できませんでした。もう一度お試しください。',
        updatedItems: null,
        tips: null,
      );
    }
  }

  /// クイックサジェスト（シンプルな質問に回答）
  Future<String> getQuickSuggestion({
    required String question,
    required String? destination,
  }) async {
    final destText = destination != null ? '（目的地: $destination）' : '';
    final prompt = '''
旅行に関する質問に簡潔に回答してください$destText。

質問: $question

【指示】
- 2-3文で簡潔に回答
- 具体的で実用的なアドバイスを
- 絵文字を1つ使って親しみやすく
''';

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);
      return response.text ?? '回答を生成できませんでした。';
    } catch (e) {
      return '回答を生成できませんでした。';
    }
  }

  /// 投票結果からの調整提案
  Future<String> suggestAdjustment({
    required String location,
    required int yesVotes,
    required int noVotes,
    required String currentPlan,
  }) async {
    final prompt = '''
旅行プランの「$location」について投票結果を分析してください。

賛成: $yesVotes票
反対: $noVotes票

現在のプラン: $currentPlan

【指示】
- 投票結果に基づいて、1文でアドバイスしてください
- 反対が多ければ代替案を、賛成が多ければ補足情報を
''';

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);
      return response.text ?? '';
    } catch (e) {
      return '';
    }
  }

  /// プレースホルダー用の提案を取得
  /// 宿泊、食事、自由時間など、プレースホルダーの種類に応じた提案を返す
  Future<PlaceholderSuggestion> suggestForPlaceholder({
    required String placeholderType,
    required String? destination,
    required String? nearbyLocation,
    required String? tripContext,
    int maxSuggestions = 5,
  }) async {
    final destText = destination != null ? '目的地: $destination' : '';
    final nearbyText = nearbyLocation != null ? '周辺: $nearbyLocation' : '';
    final contextText = tripContext ?? '';

    String prompt;
    switch (placeholderType) {
      case 'accommodation':
        prompt = '''
あなたは宿泊施設の専門家です。以下の条件で宿泊先候補を$maxSuggestions件提案してください。

【エリア情報】
$destText
$nearbyText
$contextText

【出力形式】
以下のJSON形式で出力してください:
```json
{
  "suggestions": [
    {
      "name": "宿泊施設名",
      "type": "ホテル/旅館/ゲストハウス等",
      "priceRange": "1泊の目安価格帯",
      "features": ["特徴1", "特徴2"],
      "searchQuery": "検索クエリ（地名+施設タイプ形式）"
    }
  ],
  "tips": "宿選びのアドバイス1文"
}
```

【重要な指示】
- ⚠️ 必ず指定されたエリア内の宿泊施設のみを提案すること
- ⚠️ 他の都道府県や遠い地域の施設は絶対に提案しないこと
- 価格は目安として「1万円前後」「2万円〜」のような形式で
- searchQueryは必ず「[具体的な地名] [施設タイプ/特徴]」の形式で（例: 「玉造温泉 旅館」「松江駅 ビジネスホテル」）
- 様々な価格帯・タイプを混ぜて提案
- その地域の温泉旅館や名宿があれば優先的に提案
''';
        break;

      case 'meal':
        prompt = '''
あなたはグルメガイドです。以下の条件で食事スポット候補を$maxSuggestions件提案してください。

【エリア情報】
$destText
$nearbyText
$contextText

【出力形式】
以下のJSON形式で出力してください:
```json
{
  "suggestions": [
    {
      "name": "店名または料理ジャンル",
      "type": "ジャンル（居酒屋/ラーメン/カフェ等）",
      "priceRange": "1人あたりの目安",
      "features": ["特徴1", "特徴2"],
      "searchQuery": "検索クエリ（地名+ジャンル形式）"
    }
  ],
  "tips": "食事選びのアドバイス1文"
}
```

【重要な指示】
- ⚠️ 必ず指定されたエリア内の店・ジャンルのみを提案すること
- ⚠️ 他の都道府県や遠い地域の店は絶対に提案しないこと
- 具体的な店名が分かる場合は店名を、不明な場合は「$destination周辺の海鮮居酒屋」のように地名を含めて表現
- searchQueryは必ず「[具体的な地名] [ジャンル]」の形式で（例: 「玉造温泉 居酒屋」「松江 海鮮」）
- 様々な価格帯・ジャンルを混ぜて提案
- その土地の名物・郷土料理を優先的に提案
''';
        break;

      case 'activity':
        prompt = '''
あなたは旅行アドバイザーです。以下の条件で観光・アクティビティ候補を$maxSuggestions件提案してください。

【エリア情報】
$destText
$nearbyText
$contextText

【出力形式】
以下のJSON形式で出力してください:
```json
{
  "suggestions": [
    {
      "name": "スポット名/アクティビティ名",
      "type": "観光/体験/ショッピング等",
      "duration": "所要時間目安",
      "features": ["特徴1", "特徴2"],
      "searchQuery": "検索クエリ（地名+スポット名形式）"
    }
  ],
  "tips": "楽しみ方のアドバイス1文"
}
```

【重要な指示】
- ⚠️ 必ず指定されたエリア内のスポット・アクティビティのみを提案すること
- ⚠️ 他の都道府県や遠い地域のスポットは絶対に提案しないこと
- searchQueryは必ず「[具体的な地名] [スポット名/体験名]」の形式で（例: 「玉造温泉 足湯」「松江城」）
- 有名スポットから穴場まで幅広く
- 所要時間を明記して計画の参考に
- その地域ならではの体験を優先
''';
        break;

      default:
        prompt = '''
あなたは旅行プランナーです。以下の条件で「$placeholderType」に関する候補を$maxSuggestions件提案してください。

$destText
$nearbyText
$contextText

【出力形式】
以下のJSON形式で出力してください:
```json
{
  "suggestions": [
    {
      "name": "提案名",
      "type": "種類",
      "features": ["特徴1", "特徴2"],
      "searchQuery": "検索クエリ"
    }
  ],
  "tips": "アドバイス1文"
}
```
''';
    }

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);
      final text = response.text ?? '';

      // JSONを抽出してパース
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return PlaceholderSuggestion.fromJson(json);
      }

      return PlaceholderSuggestion(suggestions: [], tips: null);
    } catch (e) {
      debugPrint('AI Placeholder Suggestion Error: $e');
      return PlaceholderSuggestion(suggestions: [], tips: null);
    }
  }
}

/// プレースホルダーの種類
enum PlaceholderType {
  accommodation, // 宿泊
  meal, // 食事（ランチ、ディナー等）
  activity, // アクティビティ、自由時間
  shopping, // 買い物
  transport, // 移動
  other, // その他
}

/// プレースホルダータイプ判定ヘルパー
class PlaceholderHelper {
  /// ロケーション文字列からプレースホルダータイプを判定
  static PlaceholderType detectType(String location) {
    final lower = location.toLowerCase();

    // 宿泊
    if (lower.contains('宿') ||
        lower.contains('ホテル') ||
        lower.contains('旅館') ||
        lower.contains('泊') ||
        lower.contains('チェックイン') ||
        lower.contains('チェックアウト')) {
      return PlaceholderType.accommodation;
    }

    // 食事
    if (lower.contains('ランチ') ||
        lower.contains('ディナー') ||
        lower.contains('朝食') ||
        lower.contains('昼食') ||
        lower.contains('夕食') ||
        lower.contains('食事') ||
        lower.contains('レストラン') ||
        lower.contains('カフェ')) {
      return PlaceholderType.meal;
    }

    // 買い物
    if (lower.contains('お土産') ||
        lower.contains('ショッピング') ||
        lower.contains('買い物')) {
      return PlaceholderType.shopping;
    }

    // 移動
    if (lower.contains('移動') || lower.contains('乗り換え')) {
      return PlaceholderType.transport;
    }

    // アクティビティ / 自由時間
    if (lower.contains('自由') ||
        lower.contains('散策') ||
        lower.contains('観光') ||
        lower.contains('体験')) {
      return PlaceholderType.activity;
    }

    return PlaceholderType.other;
  }

  /// プレースホルダータイプに応じたアイコンを取得
  static IconData getIcon(PlaceholderType type) {
    switch (type) {
      case PlaceholderType.accommodation:
        return Icons.hotel;
      case PlaceholderType.meal:
        return Icons.restaurant;
      case PlaceholderType.activity:
        return Icons.explore;
      case PlaceholderType.shopping:
        return Icons.shopping_bag;
      case PlaceholderType.transport:
        return Icons.directions_car;
      case PlaceholderType.other:
        return Icons.place;
    }
  }

  /// プレースホルダータイプに応じたラベルを取得
  static String getLabel(PlaceholderType type) {
    switch (type) {
      case PlaceholderType.accommodation:
        return '宿を探す';
      case PlaceholderType.meal:
        return 'お店を探す';
      case PlaceholderType.activity:
        return 'スポットを探す';
      case PlaceholderType.shopping:
        return 'お店を探す';
      case PlaceholderType.transport:
        return 'ルートを検索';
      case PlaceholderType.other:
        return '候補を探す';
    }
  }

  /// プレースホルダータイプに応じた外部検索URLを生成
  static String? getSearchUrl(
    PlaceholderType type,
    String query, {
    String? area,
  }) {
    final encodedQuery = Uri.encodeComponent(query);
    final areaQuery = area != null ? Uri.encodeComponent(area) : '';

    switch (type) {
      case PlaceholderType.accommodation:
        // じゃらんで検索
        return 'https://www.jalan.net/uw/uwp1100/uww1101.do?screenId=UWW1101&kenCd=&distCd=&stayYear=&stayMonth=&stayDay=&stayCount=1&roomCount=1&adultNum=2&keyword=$encodedQuery';
      case PlaceholderType.meal:
        // 食べログで検索
        return 'https://tabelog.com/rstLst/?vs=1&sw=$encodedQuery';
      case PlaceholderType.activity:
        // Googleで検索
        return 'https://www.google.com/search?q=$areaQuery+観光+$encodedQuery';
      case PlaceholderType.shopping:
        // Googleで検索
        return 'https://www.google.com/search?q=$areaQuery+$encodedQuery+お土産';
      case PlaceholderType.transport:
        // Google Mapsで検索
        return 'https://www.google.com/maps/dir/?api=1&destination=$encodedQuery';
      case PlaceholderType.other:
        return 'https://www.google.com/search?q=$encodedQuery';
    }
  }

  /// プレースホルダーからキーワードを抽出
  static String extractKeyword(String location) {
    return location
        .replaceAll('※', '')
        .replaceAll(RegExp(r'（.*?）'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll('未定', '')
        .trim();
  }
}

/// プレースホルダー提案結果
class PlaceholderSuggestion {
  final List<SuggestionItem> suggestions;
  final String? tips;

  PlaceholderSuggestion({required this.suggestions, this.tips});

  factory PlaceholderSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceholderSuggestion(
      suggestions:
          (json['suggestions'] as List<dynamic>?)
              ?.map((s) => SuggestionItem.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      tips: json['tips'],
    );
  }
}

/// 個別の提案アイテム
class SuggestionItem {
  final String name;
  final String? type;
  final String? priceRange;
  final String? duration;
  final List<String> features;
  final String searchQuery;

  SuggestionItem({
    required this.name,
    this.type,
    this.priceRange,
    this.duration,
    required this.features,
    required this.searchQuery,
  });

  factory SuggestionItem.fromJson(Map<String, dynamic> json) {
    return SuggestionItem(
      name: json['name'] ?? '',
      type: json['type'],
      priceRange: json['priceRange'],
      duration: json['duration'],
      features: List<String>.from(json['features'] ?? []),
      searchQuery: json['searchQuery'] ?? json['name'] ?? '',
    );
  }
}

/// 生成されたプラン
class GeneratedPlan {
  final String type;
  final String title;
  final String description;
  final List<PlanItemData> items;
  final List<String> includedCards;
  final List<String> excludedCards;

  GeneratedPlan({
    required this.type,
    required this.title,
    required this.description,
    required this.items,
    required this.includedCards,
    required this.excludedCards,
  });

  factory GeneratedPlan.fromJson(Map<String, dynamic> json) {
    return GeneratedPlan(
      type: json['type'] ?? 'unknown',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => PlanItemData.fromJson(i))
              .toList() ??
          [],
      includedCards: List<String>.from(json['includedCards'] ?? []),
      excludedCards: List<String>.from(json['excludedCards'] ?? []),
    );
  }

  /// PlanModelに変換
  PlanModel toPlanModel(String tripId) {
    return PlanModel(
      id: '',
      tripId: tripId,
      title: title,
      description: description,
      items:
          items
              .map(
                (i) => PlanItem(
                  day: i.day,
                  time: i.time,
                  location: i.location,
                  notes: i.notes,
                  durationMinutes: i.duration,
                  latitude: i.latitude,
                  longitude: i.longitude,
                ),
              )
              .toList(),
      includedCards: includedCards,
      excludedCards: excludedCards,
      votes: {},
      createdAt: DateTime.now(),
    );
  }
}

/// プランアイテムデータ
class PlanItemData {
  final int day;
  final String time;
  final String location;
  final int duration;
  final String? notes;
  final double? latitude;
  final double? longitude;

  PlanItemData({
    required this.day,
    required this.time,
    required this.location,
    required this.duration,
    this.notes,
    this.latitude,
    this.longitude,
  });

  factory PlanItemData.fromJson(Map<String, dynamic> json) {
    return PlanItemData(
      day: json['day'] ?? 1,
      time: json['time'] ?? '10:00',
      location: json['location'] ?? '',
      duration: json['duration'] ?? 60,
      notes: json['notes'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// AI編集提案
class PlanEditSuggestion {
  final String suggestion;
  final List<PlanItemData>? updatedItems;
  final String? tips;

  PlanEditSuggestion({required this.suggestion, this.updatedItems, this.tips});

  factory PlanEditSuggestion.fromJson(Map<String, dynamic> json) {
    List<PlanItemData>? items;
    if (json['updatedItems'] != null) {
      items =
          (json['updatedItems'] as List<dynamic>)
              .map((i) => PlanItemData.fromJson(i as Map<String, dynamic>))
              .toList();
    }

    return PlanEditSuggestion(
      suggestion: json['suggestion'] ?? '',
      updatedItems: items,
      tips: json['tips'],
    );
  }

  /// PlanItemリストに変換
  List<PlanItem>? toPlanItems() {
    if (updatedItems == null) return null;
    return updatedItems!
        .map(
          (i) => PlanItem(
            day: i.day,
            time: i.time,
            location: i.location,
            notes: i.notes,
            durationMinutes: i.duration,
            latitude: i.latitude,
            longitude: i.longitude,
          ),
        )
        .toList();
  }
}

/// プラン生成イベント（リアルタイムストリーミング用）
sealed class GenerationEvent {
  const GenerationEvent();

  /// 生成開始
  const factory GenerationEvent.started() = GenerationStarted;

  /// テキストチャンク受信
  const factory GenerationEvent.textChunk(String text) = GenerationTextChunk;

  /// プラン開始（タイトル検出）
  const factory GenerationEvent.planStarted({
    required String planType,
    required String title,
  }) = GenerationPlanStarted;

  /// アイテム生成
  const factory GenerationEvent.itemGenerated({required PlanItemData item}) =
      GenerationItemGenerated;

  /// プラン完了（1件）
  const factory GenerationEvent.planCompleted({required GeneratedPlan plan}) =
      GenerationPlanCompleted;

  /// 生成完了
  const factory GenerationEvent.completed({
    required List<GeneratedPlan> plans,
  }) = GenerationCompleted;

  /// エラー
  const factory GenerationEvent.error({required String message}) =
      GenerationError;
}

class GenerationStarted extends GenerationEvent {
  const GenerationStarted();
}

class GenerationTextChunk extends GenerationEvent {
  final String text;
  const GenerationTextChunk(this.text);
}

class GenerationPlanStarted extends GenerationEvent {
  final String planType;
  final String title;
  const GenerationPlanStarted({required this.planType, required this.title});
}

class GenerationItemGenerated extends GenerationEvent {
  final PlanItemData item;
  const GenerationItemGenerated({required this.item});
}

class GenerationPlanCompleted extends GenerationEvent {
  final GeneratedPlan plan;
  const GenerationPlanCompleted({required this.plan});
}

class GenerationCompleted extends GenerationEvent {
  final List<GeneratedPlan> plans;
  const GenerationCompleted({required this.plans});
}

class GenerationError extends GenerationEvent {
  final String message;
  const GenerationError({required this.message});
}

/// カード分析結果
class CardAnalysis {
  final List<String> keywords;
  final String topSpot;
  final String groupStyle;
  final String funFact;
  final List<MemberHighlight> memberHighlights;

  CardAnalysis({
    required this.keywords,
    required this.topSpot,
    required this.groupStyle,
    required this.funFact,
    required this.memberHighlights,
  });

  factory CardAnalysis.fromJson(Map<String, dynamic> json) {
    return CardAnalysis(
      keywords: List<String>.from(json['keywords'] ?? []),
      topSpot: json['topSpot'] ?? '',
      groupStyle: json['groupStyle'] ?? '',
      funFact: json['funFact'] ?? '',
      memberHighlights: (json['memberHighlights'] as List<dynamic>?)
              ?.map((e) => MemberHighlight.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// メンバーハイライト
class MemberHighlight {
  final String name;
  final String want;

  MemberHighlight({required this.name, required this.want});

  factory MemberHighlight.fromJson(Map<String, dynamic> json) {
    return MemberHighlight(
      name: json['name'] ?? '',
      want: json['want'] ?? '',
    );
  }
}
