import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'card_model.freezed.dart';
part 'card_model.g.dart';

/// リアクションの種類
enum ReactionType {
  /// いいね 👍
  up,

  /// まあまあ 😐
  neutral,

  /// パス 👎
  down,
}

/// カードの種類
enum CardType {
  /// 決まっていること
  confirmed('決まっていること', '✅', '現時点で決まっていることがあれば教えてください'),

  /// 行きたい場所
  place('行きたい場所', '📍', '行きたい場所'),

  /// やりたいこと
  activity('やりたいこと', '🎯', '体験したいこと'),

  /// 旅の雰囲気・希望
  atmosphere('旅の雰囲気', '✨', '旅のスタイル'),

  /// 予算・お金
  budget('予算・お金', '💰', '予算の目安'),

  /// 行きたくない場所
  avoidPlace('行きたくない場所', '🚫', '避けたい場所'),

  /// やりたくないこと
  avoidActivity('やりたくないこと', '⛔', 'これは避けたい');

  const CardType(this.label, this.emoji, this.hint);
  final String label;
  final String emoji;
  final String hint;

  /// ポジティブなカードかどうか
  bool get isPositive =>
      this == confirmed || this == place || this == activity || this == atmosphere || this == budget;

  /// ネガティブなカードかどうか
  bool get isNegative => this == avoidPlace || this == avoidActivity;

  /// 決まっていることカードかどうか
  bool get isConfirmed => this == confirmed;
}

/// カードモデル（行きたい場所・やりたいこと・希望・避けたいこと）
@freezed
class CardModel with _$CardModel {
  const factory CardModel({
    required String id,
    required String tripId,
    required String title,
    @Default(CardType.place) CardType cardType,
    String? placeId,
    String? imageUrl,
    String? description,
    required String createdBy,
    @Default(false) bool anonymous,
    @Default({}) Map<String, ReactionType> reactions,
    required DateTime createdAt,
  }) = _CardModel;

  factory CardModel.fromJson(Map<String, dynamic> json) =>
      _$CardModelFromJson(json);

  factory CardModel.fromFirestore(DocumentSnapshot doc, String tripId) {
    final data = doc.data() as Map<String, dynamic>;
    final reactionsData = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = reactionsData.map(
      (key, value) => MapEntry(
        key,
        ReactionType.values.firstWhere(
          (e) => e.name == value,
          orElse: () => ReactionType.neutral,
        ),
      ),
    );

    return CardModel(
      id: doc.id,
      tripId: tripId,
      title: data['title'] ?? '',
      cardType: CardType.values.firstWhere(
        (e) => e.name == data['cardType'],
        orElse: () => CardType.place,
      ),
      placeId: data['placeId'],
      imageUrl: data['imageUrl'],
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      anonymous: data['anonymous'] ?? false,
      reactions: reactions,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

extension CardModelExtension on CardModel {
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'cardType': cardType.name,
      'placeId': placeId,
      'imageUrl': imageUrl,
      'description': description,
      'createdBy': createdBy,
      'anonymous': anonymous,
      'reactions': reactions.map((key, value) => MapEntry(key, value.name)),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// 各リアクションの数をカウント
  int get upCount => reactions.values.where((r) => r == ReactionType.up).length;
  int get neutralCount =>
      reactions.values.where((r) => r == ReactionType.neutral).length;
  int get downCount =>
      reactions.values.where((r) => r == ReactionType.down).length;

  /// 合計スコア（いいね=+1, まあまあ=0, パス=-1）
  int get score => upCount - downCount;
}
