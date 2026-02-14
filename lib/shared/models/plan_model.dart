import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_model.freezed.dart';
part 'plan_model.g.dart';

/// プランアイテム（1つのスポット）
@freezed
class PlanItem with _$PlanItem {
  const factory PlanItem({
    @Default(1) int day,
    required String time,
    required String location,
    String? cardId,
    String? notes,
    @Default(60) int durationMinutes,
    double? latitude,
    double? longitude,

    /// プレースホルダー（ユーザーが後で埋める項目）
    @Default(false) bool isPlaceholder,

    /// 予約URL
    String? bookingUrl,

    /// 予約メモ（確認番号、予約名など）
    String? bookingNote,

    /// 予約済みフラグ
    @Default(false) bool isBooked,

    /// 予約画像URL（スクリーンショットなど）
    String? bookingImageUrl,
  }) = _PlanItem;

  factory PlanItem.fromJson(Map<String, dynamic> json) =>
      _$PlanItemFromJson(json);
}

/// プランモデル（AIが生成するプラン）
@freezed
class PlanModel with _$PlanModel {
  const factory PlanModel({
    required String id,
    required String tripId,
    required String title,
    String? description,
    String? iconUrl,
    @Default([]) List<PlanItem> items,
    @Default([]) List<String> includedCards,
    @Default([]) List<String> excludedCards,
    @Default({}) Map<String, bool> votes,
    required DateTime createdAt,
    DateTime? updatedAt,

    /// 現在編集中のユーザーID
    String? editingBy,

    /// 最後に編集したユーザー名
    String? lastEditedByName,
  }) = _PlanModel;

  factory PlanModel.fromJson(Map<String, dynamic> json) =>
      _$PlanModelFromJson(json);

  factory PlanModel.fromFirestore(DocumentSnapshot doc, String tripId) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsData = data['items'] as List<dynamic>? ?? [];
    final items =
        itemsData
            .map((item) => PlanItem.fromJson(item as Map<String, dynamic>))
            .toList();
    final votesData = data['votes'] as Map<String, dynamic>? ?? {};

    return PlanModel(
      id: doc.id,
      tripId: tripId,
      title: data['title'] ?? '',
      description: data['description'],
      iconUrl: data['iconUrl'],
      items: items,
      includedCards: List<String>.from(data['includedCards'] ?? []),
      excludedCards: List<String>.from(data['excludedCards'] ?? []),
      votes: votesData.map((key, value) => MapEntry(key, value as bool)),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
      editingBy: data['editingBy'] as String?,
      lastEditedByName: data['lastEditedByName'] as String?,
    );
  }
}

extension PlanModelExtension on PlanModel {
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'iconUrl': iconUrl,
      'items': items.map((item) => item.toJson()).toList(),
      'includedCards': includedCards,
      'excludedCards': excludedCards,
      'votes': votes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'editingBy': editingBy,
      'lastEditedByName': lastEditedByName,
    };
  }

  /// 賛成票の数
  int get yesVotes => votes.values.where((v) => v).length;

  /// 反対票の数
  int get noVotes => votes.values.where((v) => !v).length;
}
