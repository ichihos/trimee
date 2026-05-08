// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlanItemImpl _$$PlanItemImplFromJson(Map<String, dynamic> json) =>
    _$PlanItemImpl(
      id: json['id'] as String? ?? '',
      day: (json['day'] as num?)?.toInt() ?? 1,
      time: json['time'] as String,
      location: json['location'] as String,
      notes: json['notes'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      bookingUrl: json['bookingUrl'] as String?,
      bookingNote: json['bookingNote'] as String?,
      isBooked: json['isBooked'] as bool? ?? false,
      bookingImageUrl: json['bookingImageUrl'] as String?,
    );

Map<String, dynamic> _$$PlanItemImplToJson(_$PlanItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'day': instance.day,
      'time': instance.time,
      'location': instance.location,
      'notes': instance.notes,
      'durationMinutes': instance.durationMinutes,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'bookingUrl': instance.bookingUrl,
      'bookingNote': instance.bookingNote,
      'isBooked': instance.isBooked,
      'bookingImageUrl': instance.bookingImageUrl,
    };

_$PlanModelImpl _$$PlanModelImplFromJson(Map<String, dynamic> json) =>
    _$PlanModelImpl(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt:
          json['updatedAt'] == null
              ? null
              : DateTime.parse(json['updatedAt'] as String),
      editingBy: json['editingBy'] as String?,
      lastEditedByName: json['lastEditedByName'] as String?,
    );

Map<String, dynamic> _$$PlanModelImplToJson(_$PlanModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tripId': instance.tripId,
      'title': instance.title,
      'description': instance.description,
      'items': instance.items,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'editingBy': instance.editingBy,
      'lastEditedByName': instance.lastEditedByName,
    };
