import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip_member_model.freezed.dart';
part 'trip_member_model.g.dart';

/// 旅行メンバーの詳細情報
@freezed
class TripMember with _$TripMember {
  const factory TripMember({
    /// ユーザーID
    required String userId,

    /// 表示名
    required String displayName,

    /// 出発地点（例: 東京駅、新宿など）
    String? departurePoint,

    /// 手動追加フラグ（セッション外のメンバー）
    @Default(false) bool isManual,

    /// 個別リンクID（手動メンバー用）
    String? personalLinkId,

    /// 参加日時
    DateTime? joinedAt,
  }) = _TripMember;

  factory TripMember.fromJson(Map<String, dynamic> json) =>
      _$TripMemberFromJson(json);

  /// JSONからの安全な変換（null値を処理）
  static TripMember fromJsonSafe(Map<String, dynamic> json) {
    return TripMember(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      departurePoint: json['departurePoint'] as String?,
      isManual: json['isManual'] as bool? ?? false,
      personalLinkId: json['personalLinkId'] as String?,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String)
          : null,
    );
  }
}
