import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimee/shared/providers/firebase_providers.dart';
import 'package:trimee/shared/providers/user_profile_provider.dart';
import '../models/chat_model.dart';

/// チャットサービスプロバイダー
final chatServiceProvider = Provider<ChatService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ChatService(firestore: firestore);
});

/// チャットのストリームプロバイダー
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  tripId,
) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.streamMessages(tripId);
});

/// チャットコントローラー
final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
      final chatService = ref.watch(chatServiceProvider);
      final currentUserId = ref.watch(currentUserIdProvider);
      final profileAsync = ref.watch(currentUserProfileProvider);
      final senderName = profileAsync.valueOrNull?.displayName;
      return ChatController(
        chatService: chatService,
        currentUserId: currentUserId,
        senderName: senderName,
      );
    });

class ChatController extends StateNotifier<AsyncValue<void>> {
  ChatController({
    required this.chatService,
    required this.currentUserId,
    this.senderName,
  }) : super(const AsyncData(null));

  final ChatService chatService;
  final String? currentUserId;
  final String? senderName;

  Future<void> sendMessage({
    required String tripId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    if (currentUserId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => chatService.sendMessage(
        tripId: tripId,
        senderId: currentUserId!,
        senderName: senderName,
        content: content,
        type: type,
      ),
    );
  }
}

class ChatService {
  ChatService({required this.firestore});

  final FirebaseFirestore firestore;

  /// メッセージを送信
  Future<void> sendMessage({
    required String tripId,
    required String senderId,
    String? senderName,
    required String content,
    required MessageType type,
  }) async {
    final docRef =
        firestore.collection('trips').doc(tripId).collection('messages').doc();

    final message = ChatMessage(
      id: docRef.id,
      tripId: tripId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      timestamp: DateTime.now(),
    );

    await docRef.set(message.toJson());
  }

  /// メッセージをストリーム取得
  Stream<List<ChatMessage>> streamMessages(String tripId) {
    return firestore
        .collection('trips')
        .doc(tripId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromJson(doc.data()))
              .toList();
        });
  }
}
