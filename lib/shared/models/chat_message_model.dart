import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message_model.freezed.dart';
part 'chat_message_model.g.dart';

/// チャットメッセージモデル
@freezed
class ChatMessageModel with _$ChatMessageModel {
  const factory ChatMessageModel({
    required String id,
    required String tripId,
    String? userId,
    required String message,
    @Default(false) bool isAI,
    String? speakingFor,
    required DateTime timestamp,
  }) = _ChatMessageModel;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageModelFromJson(json);

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc, String tripId) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      tripId: tripId,
      userId: data['userId'],
      message: data['message'] ?? '',
      isAI: data['isAI'] ?? false,
      speakingFor: data['speakingFor'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

extension ChatMessageModelExtension on ChatMessageModel {
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'message': message,
      'isAI': isAI,
      'speakingFor': speakingFor,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
