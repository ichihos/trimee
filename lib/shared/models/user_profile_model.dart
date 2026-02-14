import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

/// 年代
enum AgeRange {
  teens('10代'),
  twenties('20代'),
  thirties('30代'),
  forties('40代'),
  fifties('50代'),
  sixtiesPlus('60代以上');

  const AgeRange(this.label);
  final String label;
}

/// 性別
enum Gender {
  male('男性'),
  female('女性'),
  other('その他'),
  preferNotToSay('回答しない');

  const Gender(this.label);
  final String label;
}

/// 旅行スタイル
enum TravelStyle {
  active('アクティブ派', '観光地をたくさん巡りたい'),
  relaxed('のんびり派', 'ゆったり過ごしたい'),
  gourmet('グルメ派', '美味しいものを食べたい'),
  photo('写真派', 'SNS映えスポットを巡りたい'),
  culture('文化派', '歴史や文化に触れたい'),
  nature('自然派', '自然の中でリフレッシュしたい'),
  shopping('ショッピング派', '買い物を楽しみたい');

  const TravelStyle(this.label, this.description);
  final String label;
  final String description;
}

/// ユーザープロフィールモデル
@freezed
class UserProfileModel with _$UserProfileModel {
  const factory UserProfileModel({
    required String userId,
    required String displayName,
    AgeRange? ageRange,
    Gender? gender,
    @Default([]) List<TravelStyle> travelStyles,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfileModel(
      userId: doc.id,
      displayName: data['displayName'] ?? '',
      ageRange: data['ageRange'] != null
          ? AgeRange.values.firstWhere(
              (e) => e.name == data['ageRange'],
              orElse: () => AgeRange.twenties,
            )
          : null,
      gender: data['gender'] != null
          ? Gender.values.firstWhere(
              (e) => e.name == data['gender'],
              orElse: () => Gender.preferNotToSay,
            )
          : null,
      travelStyles: (data['travelStyles'] as List<dynamic>?)
              ?.map((e) => TravelStyle.values.firstWhere(
                    (s) => s.name == e,
                    orElse: () => TravelStyle.active,
                  ))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

extension UserProfileModelExtension on UserProfileModel {
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'ageRange': ageRange?.name,
      'gender': gender?.name,
      'travelStyles': travelStyles.map((e) => e.name).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// AIプロンプト用の説明文
  String toPromptDescription() {
    final parts = <String>[];
    parts.add(displayName);
    if (ageRange != null) {
      parts.add(ageRange!.label);
    }
    if (gender != null && gender != Gender.preferNotToSay) {
      parts.add(gender!.label);
    }
    if (travelStyles.isNotEmpty) {
      parts.add('好み: ${travelStyles.map((e) => e.label).join(', ')}');
    }
    return parts.join(' / ');
  }
}
