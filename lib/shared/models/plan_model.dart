import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_model.freezed.dart';
part 'plan_model.g.dart';

/// しおりアイテム（1つのスポット/予定）
@freezed
class PlanItem with _$PlanItem {
  const factory PlanItem({
    @Default('') String id,
    @Default(1) int day,
    required String time,
    required String location,
    String? notes,
    @Default(60) int durationMinutes,
    double? latitude,
    double? longitude,

    /// 位置の精度半径（メートル）— AIジオコーディングの確信度
    double? locationRadius,

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

/// しおりプランモデル
@freezed
class PlanModel with _$PlanModel {
  const factory PlanModel({
    required String id,
    required String tripId,
    required String title,
    String? description,
    @Default([]) List<PlanItem> items,
    required DateTime createdAt,
    DateTime? updatedAt,

    /// 現在編集中のユーザーID（共同編集ロック用）
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

    return PlanModel(
      id: doc.id,
      tripId: tripId,
      title: data['title'] ?? '',
      description: data['description'],
      items: items,
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
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'editingBy': editingBy,
      'lastEditedByName': lastEditedByName,
    };
  }
}
