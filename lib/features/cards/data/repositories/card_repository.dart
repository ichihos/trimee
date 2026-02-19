import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/card_model.dart';

/// カードリポジトリ
class CardRepository {
  CardRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _cardsCollection(String tripId) =>
      _firestore.collection('trips').doc(tripId).collection('cards');

  /// カードを作成
  Future<String> createCard({
    required String tripId,
    required String title,
    required String createdBy,
    CardType cardType = CardType.place,
    String? placeId,
    String? imageUrl,
    String? description,
    bool anonymous = false,
  }) async {
    final card = CardModel(
      id: '',
      tripId: tripId,
      title: title,
      cardType: cardType,
      placeId: placeId,
      imageUrl: imageUrl,
      description: description,
      createdBy: createdBy,
      anonymous: anonymous,
      reactions: {},
      createdAt: DateTime.now(),
    );

    final doc = await _cardsCollection(tripId).add(card.toFirestore());
    return doc.id;
  }

  /// カード一覧を監視
  Stream<List<CardModel>> watchCards(String tripId) {
    return _cardsCollection(tripId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CardModel.fromFirestore(doc, tripId))
                  .toList(),
        );
  }

  /// カードを取得
  Future<CardModel?> getCard(String tripId, String cardId) async {
    final doc = await _cardsCollection(tripId).doc(cardId).get();
    if (doc.exists) {
      return CardModel.fromFirestore(doc, tripId);
    }
    return null;
  }

  /// リアクションを追加/更新
  Future<void> updateReaction({
    required String tripId,
    required String cardId,
    required String userId,
    required ReactionType reaction,
  }) async {
    await _cardsCollection(
      tripId,
    ).doc(cardId).update({'reactions.$userId': reaction.name});
  }

  /// リアクションを削除
  Future<void> removeReaction({
    required String tripId,
    required String cardId,
    required String userId,
  }) async {
    await _cardsCollection(
      tripId,
    ).doc(cardId).update({'reactions.$userId': FieldValue.delete()});
  }

  /// カードを更新
  Future<void> updateCard({
    required String tripId,
    required String cardId,
    required String title,
    required CardType cardType,
  }) async {
    await _cardsCollection(
      tripId,
    ).doc(cardId).update({'title': title, 'cardType': cardType.name});
  }

  /// カードを削除
  Future<void> deleteCard(String tripId, String cardId) async {
    await _cardsCollection(tripId).doc(cardId).delete();
  }
}
