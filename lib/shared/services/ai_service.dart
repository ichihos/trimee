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
}
