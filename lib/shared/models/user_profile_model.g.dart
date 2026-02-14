// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserProfileModelImpl _$$UserProfileModelImplFromJson(
  Map<String, dynamic> json,
) => _$UserProfileModelImpl(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String,
  ageRange: $enumDecodeNullable(_$AgeRangeEnumMap, json['ageRange']),
  gender: $enumDecodeNullable(_$GenderEnumMap, json['gender']),
  travelStyles:
      (json['travelStyles'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$TravelStyleEnumMap, e))
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$UserProfileModelImplToJson(
  _$UserProfileModelImpl instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'displayName': instance.displayName,
  'ageRange': _$AgeRangeEnumMap[instance.ageRange],
  'gender': _$GenderEnumMap[instance.gender],
  'travelStyles':
      instance.travelStyles.map((e) => _$TravelStyleEnumMap[e]!).toList(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$AgeRangeEnumMap = {
  AgeRange.teens: 'teens',
  AgeRange.twenties: 'twenties',
  AgeRange.thirties: 'thirties',
  AgeRange.forties: 'forties',
  AgeRange.fifties: 'fifties',
  AgeRange.sixtiesPlus: 'sixtiesPlus',
};

const _$GenderEnumMap = {
  Gender.male: 'male',
  Gender.female: 'female',
  Gender.other: 'other',
  Gender.preferNotToSay: 'preferNotToSay',
};

const _$TravelStyleEnumMap = {
  TravelStyle.active: 'active',
  TravelStyle.relaxed: 'relaxed',
  TravelStyle.gourmet: 'gourmet',
  TravelStyle.photo: 'photo',
  TravelStyle.culture: 'culture',
  TravelStyle.nature: 'nature',
  TravelStyle.shopping: 'shopping',
};
