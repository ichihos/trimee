// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TripModelImpl _$$TripModelImplFromJson(
  Map<String, dynamic> json,
) => _$TripModelImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  createdBy: json['createdBy'] as String,
  members:
      (json['members'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  memberDetails:
      (json['memberDetails'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, TripMember.fromJson(e as Map<String, dynamic>)),
      ) ??
      const {},
  startDate:
      json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
  endDate:
      json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
  planId: json['planId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$TripModelImplToJson(_$TripModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'createdBy': instance.createdBy,
      'members': instance.members,
      'memberDetails': instance.memberDetails,
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'planId': instance.planId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
