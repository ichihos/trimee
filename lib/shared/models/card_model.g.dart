// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CardModelImpl _$$CardModelImplFromJson(Map<String, dynamic> json) =>
    _$CardModelImpl(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      title: json['title'] as String,
      cardType:
          $enumDecodeNullable(_$CardTypeEnumMap, json['cardType']) ??
          CardType.place,
      placeId: json['placeId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String,
      anonymous: json['anonymous'] as bool? ?? false,
      reactions:
          (json['reactions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, $enumDecode(_$ReactionTypeEnumMap, e)),
          ) ??
          const {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$CardModelImplToJson(_$CardModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tripId': instance.tripId,
      'title': instance.title,
      'cardType': _$CardTypeEnumMap[instance.cardType]!,
      'placeId': instance.placeId,
      'imageUrl': instance.imageUrl,
      'description': instance.description,
      'createdBy': instance.createdBy,
      'anonymous': instance.anonymous,
      'reactions': instance.reactions.map(
        (k, e) => MapEntry(k, _$ReactionTypeEnumMap[e]!),
      ),
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$CardTypeEnumMap = {
  CardType.confirmed: 'confirmed',
  CardType.place: 'place',
  CardType.activity: 'activity',
  CardType.atmosphere: 'atmosphere',
  CardType.budget: 'budget',
  CardType.avoidPlace: 'avoidPlace',
  CardType.avoidActivity: 'avoidActivity',
};

const _$ReactionTypeEnumMap = {
  ReactionType.up: 'up',
  ReactionType.neutral: 'neutral',
  ReactionType.down: 'down',
};
