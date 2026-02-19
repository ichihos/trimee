import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/card_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/providers/guest_session_provider.dart';
import '../../data/repositories/card_repository.dart';

const _uuid = Uuid();

/// カードリポジトリプロバイダー
final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(firestore: ref.watch(firestoreProvider));
});

/// ゲスト用ローカルカードストレージ
final localCardsProvider =
    StateNotifierProvider<LocalCardsNotifier, Map<String, List<CardModel>>>((
      ref,
    ) {
      return LocalCardsNotifier();
    });

/// ローカルカードストレージのNotifier
class LocalCardsNotifier extends StateNotifier<Map<String, List<CardModel>>> {
  LocalCardsNotifier() : super({});

  /// カードを追加
  String addCard({
    required String tripId,
    required String title,
    required String createdBy,
    CardType cardType = CardType.place,
    String? placeId,
    String? imageUrl,
    String? description,
    bool anonymous = false,
  }) {
    final cardId = _uuid.v4();
    final card = CardModel(
      id: cardId,
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
    final tripCards = state[tripId] ?? [];
    state = {
      ...state,
      tripId: [...tripCards, card],
    };
    return cardId;
  }

  /// カード一覧を取得
  List<CardModel> getCards(String tripId) {
    return state[tripId] ?? [];
  }

  /// リアクションを更新
  void updateReaction(
    String tripId,
    String cardId,
    String userId,
    ReactionType reaction,
  ) {
    final tripCards = state[tripId] ?? [];
    final updatedCards =
        tripCards.map((card) {
          if (card.id == cardId) {
            final newReactions = Map<String, ReactionType>.from(card.reactions);
            newReactions[userId] = reaction;
            return card.copyWith(reactions: newReactions);
          }
          return card;
        }).toList();
    state = {...state, tripId: updatedCards};
  }

  /// カードの内容を更新
  void updateCardContent(
    String tripId,
    String cardId, {
    required String title,
    required CardType cardType,
  }) {
    final tripCards = state[tripId] ?? [];
    final updatedCards =
        tripCards.map((card) {
          if (card.id == cardId) {
            return card.copyWith(title: title, cardType: cardType);
          }
          return card;
        }).toList();
    state = {...state, tripId: updatedCards};
  }

  /// カードを削除
  void deleteCard(String tripId, String cardId) {
    final tripCards = state[tripId] ?? [];
    state = {...state, tripId: tripCards.where((c) => c.id != cardId).toList()};
  }
}

/// 旅行のカード一覧プロバイダー
final tripCardsProvider = StreamProvider.family<List<CardModel>, String>((
  ref,
  tripId,
) {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  // ゲストユーザーの場合はローカルストレージから取得
  if (isGuest && !isAuthenticated) {
    final localCards = ref.watch(localCardsProvider)[tripId] ?? [];
    return Stream.value(localCards);
  }

  return ref.watch(cardRepositoryProvider).watchCards(tripId);
});

/// カードコントローラープロバイダー
final cardControllerProvider =
    StateNotifierProvider<CardController, AsyncValue<void>>((ref) {
      return CardController(
        ref: ref,
        repository: ref.watch(cardRepositoryProvider),
        currentUserId: ref.watch(currentUserIdProvider),
        isGuest:
            ref.watch(isGuestModeProvider) &&
            !ref.watch(isAuthenticatedProvider),
      );
    });

/// カードコントローラー
class CardController extends StateNotifier<AsyncValue<void>> {
  CardController({
    required Ref ref,
    required CardRepository repository,
    required String? currentUserId,
    required bool isGuest,
  }) : _ref = ref,
       _repository = repository,
       _currentUserId = currentUserId,
       _isGuest = isGuest,
       super(const AsyncValue.data(null));

  final Ref _ref;
  final CardRepository _repository;
  final String? _currentUserId;
  final bool _isGuest;

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
      String cardId;

      if (_isGuest) {
        // ゲストユーザーはローカルストレージに保存
        cardId = _ref
            .read(localCardsProvider.notifier)
            .addCard(
              tripId: tripId,
              title: title,
              createdBy: userId,
              cardType: cardType,
              placeId: placeId,
              imageUrl: imageUrl,
              description: description,
              anonymous: anonymous,
            );
      } else {
        // 認証済みユーザーはFirebaseに保存
        cardId = await _repository.createCard(
          tripId: tripId,
          title: title,
          createdBy: userId,
          cardType: cardType,
          placeId: placeId,
          imageUrl: imageUrl,
          description: description,
          anonymous: anonymous,
        );
      }

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
      if (_isGuest) {
        _ref
            .read(localCardsProvider.notifier)
            .updateReaction(tripId, cardId, userId, reaction);
        state = const AsyncValue.data(null);
      } else {
        state = await AsyncValue.guard(
          () => _repository.updateReaction(
            tripId: tripId,
            cardId: cardId,
            userId: userId,
            reaction: reaction,
          ),
        );
      }
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
      if (_isGuest) {
        _ref
            .read(localCardsProvider.notifier)
            .updateCardContent(
              tripId,
              cardId,
              title: title,
              cardType: cardType,
            );
        state = const AsyncValue.data(null);
      } else {
        state = await AsyncValue.guard(
          () => _repository.updateCard(
            tripId: tripId,
            cardId: cardId,
            title: title,
            cardType: cardType,
          ),
        );
      }
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
      if (_isGuest) {
        _ref.read(localCardsProvider.notifier).deleteCard(tripId, cardId);
        state = const AsyncValue.data(null);
      } else {
        state = await AsyncValue.guard(
          () => _repository.deleteCard(tripId, cardId),
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
