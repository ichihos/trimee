import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'trip_member_model.dart';

part 'trip_model.freezed.dart';
part 'trip_model.g.dart';

/// 旅行のステータス
enum TripStatus {
  /// メンバー待機中（ロビー）
  lobby,

  /// カード集め中
  collecting,

  /// 投票中
  voting,

  /// プラン確定済み
  confirmed,

  /// 旅行中（当日モード）
  ongoing,
}

/// 旅行モデル
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
    @Default(TripStatus.collecting) TripStatus status,
    String? confirmedPlanId,
    String? editingPlanId,

    /// AI生成回数（旅行単位でのマネタイズ管理用）
    @Default(0) int aiGenerationCount,

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TripModel;

  factory TripModel.fromJson(Map<String, dynamic> json) =>
      _$TripModelFromJson(json);

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // memberDetails のパース（null値を安全に処理）
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
      status: TripStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TripStatus.collecting,
      ),
      confirmedPlanId: data['confirmedPlanId'],
      editingPlanId: data['editingPlanId'],
      aiGenerationCount: data['aiGenerationCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

extension TripModelExtension on TripModel {
  Map<String, dynamic> toFirestore() {
    // memberDetails をシリアライズ
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
      'status': status.name,
      'confirmedPlanId': confirmedPlanId,
      'editingPlanId': editingPlanId,
      'aiGenerationCount': aiGenerationCount,
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
