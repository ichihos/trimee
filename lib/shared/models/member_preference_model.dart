import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'member_preference_model.freezed.dart';
part 'member_preference_model.g.dart';

/// メンバーの希望・制約メモ（不在者代弁AI用）
@freezed
class MemberPreferenceModel with _$MemberPreferenceModel {
  const factory MemberPreferenceModel({
    required String id,
    required String tripId,
    required String userId,
    @Default('') String notes,
    @Default([]) List<String> mustVisit,
    @Default([]) List<String> avoid,
  }) = _MemberPreferenceModel;

  factory MemberPreferenceModel.fromJson(Map<String, dynamic> json) =>
      _$MemberPreferenceModelFromJson(json);

  factory MemberPreferenceModel.fromFirestore(
      DocumentSnapshot doc, String tripId) {
    final data = doc.data() as Map<String, dynamic>;
    return MemberPreferenceModel(
      id: doc.id,
      tripId: tripId,
      userId: doc.id,
      notes: data['notes'] ?? '',
      mustVisit: List<String>.from(data['mustVisit'] ?? []),
      avoid: List<String>.from(data['avoid'] ?? []),
    );
  }
}

extension MemberPreferenceModelExtension on MemberPreferenceModel {
  Map<String, dynamic> toFirestore() {
    return {
      'notes': notes,
      'mustVisit': mustVisit,
      'avoid': avoid,
    };
  }
}
