// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_member_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TripMemberImpl _$$TripMemberImplFromJson(Map<String, dynamic> json) =>
    _$TripMemberImpl(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      departurePoint: json['departurePoint'] as String?,
      isManual: json['isManual'] as bool? ?? false,
      personalLinkId: json['personalLinkId'] as String?,
      joinedAt:
          json['joinedAt'] == null
              ? null
              : DateTime.parse(json['joinedAt'] as String),
    );

Map<String, dynamic> _$$TripMemberImplToJson(_$TripMemberImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'displayName': instance.displayName,
      'departurePoint': instance.departurePoint,
      'isManual': instance.isManual,
      'personalLinkId': instance.personalLinkId,
      'joinedAt': instance.joinedAt?.toIso8601String(),
    };
