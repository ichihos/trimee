// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'itinerary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ItineraryItemImpl _$$ItineraryItemImplFromJson(Map<String, dynamic> json) =>
    _$ItineraryItemImpl(
      time: json['time'] as String,
      location: json['location'] as String,
      activity: json['activity'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      notes: json['notes'] as String?,
      votes:
          (json['votes'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const {},
    );

Map<String, dynamic> _$$ItineraryItemImplToJson(_$ItineraryItemImpl instance) =>
    <String, dynamic>{
      'time': instance.time,
      'location': instance.location,
      'activity': instance.activity,
      'durationMinutes': instance.durationMinutes,
      'notes': instance.notes,
      'votes': instance.votes,
    };

_$ItineraryModelImpl _$$ItineraryModelImplFromJson(Map<String, dynamic> json) =>
    _$ItineraryModelImpl(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      date: DateTime.parse(json['date'] as String),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => ItineraryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ItineraryModelImplToJson(
  _$ItineraryModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'tripId': instance.tripId,
  'date': instance.date.toIso8601String(),
  'items': instance.items,
};
