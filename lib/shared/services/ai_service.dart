import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plan_model.dart';

/// AIサービスプロバイダー
final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

/// AIサービス
/// 画像解析によるしおりインポートのみ
class AIService {
  // Gemini Flash（低コスト・高速）- 画像解析用
  GenerativeModel get _flashModel => FirebaseAI.vertexAI(
    location: 'global',
  ).generativeModel(model: 'gemini-3-flash-preview');

  /// デバッグ用: トークン使用量をログ出力
  static void _logTokenUsage(String method, String model, GenerateContentResponse? response) {
    final meta = response?.usageMetadata;
    if (meta == null) {
      debugPrint('🔢 [$method] ($model) トークン情報なし');
      return;
    }
    debugPrint(
      '🔢 [$method] ($model) '
      'prompt: ${meta.promptTokenCount}, '
      'candidates: ${meta.candidatesTokenCount}, '
      'total: ${meta.totalTokenCount}',
    );
  }

  /// 画像からしおりアイテムを解析
  /// LINEのスクリーンショットやメモ画像などから旅程を抽出
  Future<List<PlanItem>> analyzeImageForItinerary({
    required Uint8List imageBytes,
    required String mimeType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dateInfo = startDate != null
        ? '旅行期間: ${startDate.month}/${startDate.day}${endDate != null ? ' - ${endDate.month}/${endDate.day}' : ''}'
        : '';

    final prompt = '''
この画像は旅行の計画に関するスクリーンショットまたはメモです。
画像から旅行の予定（場所、時間、アクティビティなど）を読み取り、
以下のJSON形式で旅程アイテムのリストを返してください。

$dateInfo

JSON形式:
{
  "items": [
    {
      "day": 1,
      "time": "10:00",
      "location": "場所名",
      "notes": "メモや詳細（あれば）",
      "durationMinutes": 60
    }
  ]
}

ルール:
- 読み取れる情報のみを含めてください
- 時間が不明な場合は"09:00"から1時間間隔で設定してください
- dayは1から始まる連番にしてください
- 場所が読み取れない場合は、活動内容を location に入れてください
- 予約情報（予約番号、URLなど）があれば notes に含めてください
- JSON以外のテキストは出力しないでください
''';

    try {
      final response = await _flashModel.generateContent([
        Content.multi([
          InlineDataPart(mimeType, imageBytes),
          TextPart(prompt),
        ]),
      ]);

      _logTokenUsage('analyzeImageForItinerary', 'flash', response);

      final text = response.text ?? '';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) return [];

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final itemsJson = json['items'] as List<dynamic>? ?? [];

      return itemsJson.map((item) {
        final map = item as Map<String, dynamic>;
        return PlanItem(
          id: '',
          day: map['day'] as int? ?? 1,
          time: map['time'] as String? ?? '09:00',
          location: map['location'] as String? ?? '',
          notes: map['notes'] as String?,
          durationMinutes: map['durationMinutes'] as int? ?? 60,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Image analysis failed: $e');
      return [];
    }
  }

  /// しおりアイテムの位置情報をAIで一括推定
  /// 場所名・メモ・旅行全体のコンテキストから座標と精度半径を返す
  Future<List<PlanItem>> geocodeItems({
    required List<PlanItem> items,
    String? tripTitle,
  }) async {
    if (items.isEmpty) return items;

    final itemsJson = items.asMap().entries.map((e) => {
      'index': e.key,
      'location': e.value.location,
      'notes': e.value.notes ?? '',
      'day': e.value.day,
    }).toList();

    final prompt = '''
あなたは旅行プランの場所名から緯度経度を推定するジオコーダーです。
${tripTitle != null && tripTitle.isNotEmpty ? '旅行タイトル: $tripTitle' : ''}

以下の旅程アイテムそれぞれに対して、最も妥当な緯度・経度・位置精度半径(メートル)を推定してください。

旅程:
${jsonEncode(itemsJson)}

推定ルール:
- 具体的な施設名・ランドマーク → 正確な座標、radiusは100以下
- 駅名・エリア名 → そのエリアの中心、radiusは500〜2000
- 「ランチ」「ホテル」など曖昧な行程 → 前後の行程や旅行タイトルから推定し、radiusは2000〜10000
- 推定不能な場合でも旅行全体のコンテキストからベストエフォートで推定してください
- radiusは位置の不確実さを表します（小さいほど確信度が高い）

JSON形式で返してください（JSON以外のテキストは出力しないでください）:
{
  "locations": [
    {"index": 0, "latitude": 35.6586, "longitude": 139.7454, "radius": 50},
    {"index": 1, "latitude": 35.6762, "longitude": 139.6503, "radius": 3000}
  ]
}
''';

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);

      _logTokenUsage('geocodeItems', 'flash', response);

      final text = response.text ?? '';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) return items;

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final locations = json['locations'] as List<dynamic>? ?? [];

      final result = List<PlanItem>.from(items);
      for (final loc in locations) {
        final map = loc as Map<String, dynamic>;
        final index = map['index'] as int?;
        if (index == null || index < 0 || index >= result.length) continue;

        final lat = (map['latitude'] as num?)?.toDouble();
        final lng = (map['longitude'] as num?)?.toDouble();
        final radius = (map['radius'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        result[index] = result[index].copyWith(
          latitude: lat,
          longitude: lng,
          locationRadius: radius ?? 1000,
        );
      }
      return result;
    } catch (e) {
      debugPrint('❌ Geocoding failed: $e');
      return items;
    }
  }
}
