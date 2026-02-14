// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageModelImpl _$$ChatMessageModelImplFromJson(
  Map<String, dynamic> json,
) => _$ChatMessageModelImpl(
  id: json['id'] as String,
  tripId: json['tripId'] as String,
  userId: json['userId'] as String?,
  message: json['message'] as String,
  isAI: json['isAI'] as bool? ?? false,
  speakingFor: json['speakingFor'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$$ChatMessageModelImplToJson(
  _$ChatMessageModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'tripId': instance.tripId,
  'userId': instance.userId,
  'message': instance.message,
  'isAI': instance.isAI,
  'speakingFor': instance.speakingFor,
  'timestamp': instance.timestamp.toIso8601String(),
};
