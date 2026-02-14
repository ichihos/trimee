import 'package:cloud_firestore/cloud_firestore.dart';

/// メッセージタイプ
enum MessageType {
  text, // テキストメッセージ
  reaction, // リアクション（いいね、バッドなど）
}

extension MessageTypeExt on MessageType {
  String get name => toString().split('.').last;

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}

/// チャットメッセージモデル
class ChatMessage {
  final String id;
  final String tripId;
  final String senderId;
  final String? senderName; // 投稿者名
  final String content;
  final MessageType type;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.tripId,
    required this.senderId,
    this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String?,
      content: json['content'] as String,
      type: MessageTypeExt.fromString(json['type'] as String),
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
