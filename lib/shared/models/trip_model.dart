import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'trip_member_model.dart';

part 'trip_model.freezed.dart';
part 'trip_model.g.dart';

/// しおりモデル（旧TripModel）
@freezed
class TripModel with _$TripModel {
  const factory TripModel({
    required String id,
    required String title,
    required String createdBy,
    @Default([]) List<String> members,

    /// メンバー詳細情報（キー: userId）
    @Default({}) Map<String, TripMember> memberDetails,
    DateTime? startDate,
    DateTime? endDate,

    /// しおりのプランID（1トリップに1プラン）
    String? planId,

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TripModel;

  factory TripModel.fromJson(Map<String, dynamic> json) =>
      _$TripModelFromJson(json);

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // memberDetails のパース
    final memberDetailsData = data['memberDetails'] as Map<String, dynamic>?;
    final memberDetails = <String, TripMember>{};
    if (memberDetailsData != null) {
      for (final entry in memberDetailsData.entries) {
        memberDetails[entry.key] = TripMember.fromJsonSafe(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    return TripModel(
      id: doc.id,
      title: data['title'] ?? '',
      createdBy: data['createdBy'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      memberDetails: memberDetails,
      startDate:
          data['startDate'] != null
              ? (data['startDate'] as Timestamp).toDate()
              : null,
      endDate:
          data['endDate'] != null
              ? (data['endDate'] as Timestamp).toDate()
              : null,
      planId: data['planId'] ?? data['confirmedPlanId'] ?? data['editingPlanId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

extension TripModelExtension on TripModel {
  Map<String, dynamic> toFirestore() {
    final memberDetailsMap = <String, dynamic>{};
    for (final entry in memberDetails.entries) {
      memberDetailsMap[entry.key] = entry.value.toJson();
    }

    return {
      'title': title,
      'createdBy': createdBy,
      'members': members,
      'memberDetails': memberDetailsMap,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'planId': planId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// 日程のフォーマット（例: 2/15-17）
  String get formattedDateRange {
    if (startDate == null) return '日程未定';
    if (endDate == null) return '${startDate!.month}/${startDate!.day}';
    if (startDate!.month == endDate!.month) {
      return '${startDate!.month}/${startDate!.day}-${endDate!.day}';
    }
    return '${startDate!.month}/${startDate!.day}-${endDate!.month}/${endDate!.day}';
  }
}
