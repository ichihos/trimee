import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'itinerary_model.freezed.dart';
part 'itinerary_model.g.dart';

/// 旅程アイテム
@freezed
class ItineraryItem with _$ItineraryItem {
  const factory ItineraryItem({
    required String time,
    required String location,
    String? activity,
    @Default(60) int durationMinutes,
    String? notes,
    @Default({}) Map<String, bool> votes,
  }) = _ItineraryItem;

  factory ItineraryItem.fromJson(Map<String, dynamic> json) =>
      _$ItineraryItemFromJson(json);
}

/// 旅程モデル（日ごとの予定）
@freezed
class ItineraryModel with _$ItineraryModel {
  const factory ItineraryModel({
    required String id,
    required String tripId,
    required DateTime date,
    @Default([]) List<ItineraryItem> items,
  }) = _ItineraryModel;

  factory ItineraryModel.fromJson(Map<String, dynamic> json) =>
      _$ItineraryModelFromJson(json);

  factory ItineraryModel.fromFirestore(DocumentSnapshot doc, String tripId) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsData = data['items'] as List<dynamic>? ?? [];
    final items = itemsData
        .map((item) => ItineraryItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return ItineraryModel(
      id: doc.id,
      tripId: tripId,
      date: (data['date'] as Timestamp).toDate(),
      items: items,
    );
  }
}

extension ItineraryModelExtension on ItineraryModel {
  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// 日付のフォーマット（例: 2/15(土)）
  String get formattedDate {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}/${date.day}($weekday)';
  }
}
