// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_preference_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MemberPreferenceModelImpl _$$MemberPreferenceModelImplFromJson(
  Map<String, dynamic> json,
) => _$MemberPreferenceModelImpl(
  id: json['id'] as String,
  tripId: json['tripId'] as String,
  userId: json['userId'] as String,
  notes: json['notes'] as String? ?? '',
  mustVisit:
      (json['mustVisit'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  avoid:
      (json['avoid'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$$MemberPreferenceModelImplToJson(
  _$MemberPreferenceModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'tripId': instance.tripId,
  'userId': instance.userId,
  'notes': instance.notes,
  'mustVisit': instance.mustVisit,
  'avoid': instance.avoid,
};
