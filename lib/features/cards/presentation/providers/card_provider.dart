import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/card_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../data/repositories/card_repository.dart';

/// カードリポジトリプロバイダー
final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(firestore: ref.watch(firestoreProvider));
});

/// 旅行のカード一覧プロバイダー（常にFirestoreストリーム）
final tripCardsProvider = StreamProvider.family<List<CardModel>, String>((
  ref,
  tripId,
) {
  return ref.watch(cardRepositoryProvider).watchCards(tripId);
});

/// カードコントローラープロバイダー
final cardControllerProvider =
    StateNotifierProvider<CardController, AsyncValue<void>>((ref) {
      return CardController(
        repository: ref.watch(cardRepositoryProvider),
        currentUserId: ref.watch(currentUserIdProvider),
      );
    });

/// カードコントローラー
class CardController extends StateNotifier<AsyncValue<void>> {
  CardController({
    required CardRepository repository,
    required String? currentUserId,
  }) : _repository = repository,
       _currentUserId = currentUserId,
       super(const AsyncValue.data(null));

  final CardRepository _repository;
  final String? _currentUserId;

  /// カードを作成
  Future<String?> createCard({
    required String tripId,
    required String title,
    CardType cardType = CardType.place,
    String? placeId,
    String? imageUrl,
    String? description,
    bool anonymous = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    state = const AsyncValue.loading();
    try {
      final cardId = await _repository.createCard(
        tripId: tripId,
        title: title,
        createdBy: userId,
        cardType: cardType,
        placeId: placeId,
        imageUrl: imageUrl,
        description: description,
        anonymous: anonymous,
      );

      state = const AsyncValue.data(null);
      return cardId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// リアクションを追加/更新
  Future<void> react({
    required String tripId,
    required String cardId,
    required ReactionType reaction,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;

    state = const AsyncValue.loading();
    try {
      state = await AsyncValue.guard(
        () => _repository.updateReaction(
          tripId: tripId,
          cardId: cardId,
          userId: userId,
          reaction: reaction,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// カードを更新
  Future<void> updateCard({
    required String tripId,
    required String cardId,
    required String title,
    required CardType cardType,
  }) async {
    state = const AsyncValue.loading();
    try {
      state = await AsyncValue.guard(
        () => _repository.updateCard(
          tripId: tripId,
          cardId: cardId,
          title: title,
          cardType: cardType,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// カードを削除
  Future<void> deleteCard({
    required String tripId,
    required String cardId,
  }) async {
    state = const AsyncValue.loading();
    try {
      state = await AsyncValue.guard(
        () => _repository.deleteCard(tripId, cardId),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
