// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trip_member_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TripMember _$TripMemberFromJson(Map<String, dynamic> json) {
  return _TripMember.fromJson(json);
}

/// @nodoc
mixin _$TripMember {
  /// ユーザーID
  String get userId => throw _privateConstructorUsedError;

  /// 表示名
  String get displayName => throw _privateConstructorUsedError;

  /// 出発地点（例: 東京駅、新宿など）
  String? get departurePoint => throw _privateConstructorUsedError;

  /// 手動追加フラグ（セッション外のメンバー）
  bool get isManual => throw _privateConstructorUsedError;

  /// 個別リンクID（手動メンバー用）
  String? get personalLinkId => throw _privateConstructorUsedError;

  /// 参加日時
  DateTime? get joinedAt => throw _privateConstructorUsedError;

  /// Serializes this TripMember to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TripMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TripMemberCopyWith<TripMember> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TripMemberCopyWith<$Res> {
  factory $TripMemberCopyWith(
    TripMember value,
    $Res Function(TripMember) then,
  ) = _$TripMemberCopyWithImpl<$Res, TripMember>;
  @useResult
  $Res call({
    String userId,
    String displayName,
    String? departurePoint,
    bool isManual,
    String? personalLinkId,
    DateTime? joinedAt,
  });
}

/// @nodoc
class _$TripMemberCopyWithImpl<$Res, $Val extends TripMember>
    implements $TripMemberCopyWith<$Res> {
  _$TripMemberCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TripMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? displayName = null,
    Object? departurePoint = freezed,
    Object? isManual = null,
    Object? personalLinkId = freezed,
    Object? joinedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            displayName:
                null == displayName
                    ? _value.displayName
                    : displayName // ignore: cast_nullable_to_non_nullable
                        as String,
            departurePoint:
                freezed == departurePoint
                    ? _value.departurePoint
                    : departurePoint // ignore: cast_nullable_to_non_nullable
                        as String?,
            isManual:
                null == isManual
                    ? _value.isManual
                    : isManual // ignore: cast_nullable_to_non_nullable
                        as bool,
            personalLinkId:
                freezed == personalLinkId
                    ? _value.personalLinkId
                    : personalLinkId // ignore: cast_nullable_to_non_nullable
                        as String?,
            joinedAt:
                freezed == joinedAt
                    ? _value.joinedAt
                    : joinedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TripMemberImplCopyWith<$Res>
    implements $TripMemberCopyWith<$Res> {
  factory _$$TripMemberImplCopyWith(
    _$TripMemberImpl value,
    $Res Function(_$TripMemberImpl) then,
  ) = __$$TripMemberImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String userId,
    String displayName,
    String? departurePoint,
    bool isManual,
    String? personalLinkId,
    DateTime? joinedAt,
  });
}

/// @nodoc
class __$$TripMemberImplCopyWithImpl<$Res>
    extends _$TripMemberCopyWithImpl<$Res, _$TripMemberImpl>
    implements _$$TripMemberImplCopyWith<$Res> {
  __$$TripMemberImplCopyWithImpl(
    _$TripMemberImpl _value,
    $Res Function(_$TripMemberImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TripMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? displayName = null,
    Object? departurePoint = freezed,
    Object? isManual = null,
    Object? personalLinkId = freezed,
    Object? joinedAt = freezed,
  }) {
    return _then(
      _$TripMemberImpl(
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        displayName:
            null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                    as String,
        departurePoint:
            freezed == departurePoint
                ? _value.departurePoint
                : departurePoint // ignore: cast_nullable_to_non_nullable
                    as String?,
        isManual:
            null == isManual
                ? _value.isManual
                : isManual // ignore: cast_nullable_to_non_nullable
                    as bool,
        personalLinkId:
            freezed == personalLinkId
                ? _value.personalLinkId
                : personalLinkId // ignore: cast_nullable_to_non_nullable
                    as String?,
        joinedAt:
            freezed == joinedAt
                ? _value.joinedAt
                : joinedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TripMemberImpl implements _TripMember {
  const _$TripMemberImpl({
    required this.userId,
    required this.displayName,
    this.departurePoint,
    this.isManual = false,
    this.personalLinkId,
    this.joinedAt,
  });

  factory _$TripMemberImpl.fromJson(Map<String, dynamic> json) =>
      _$$TripMemberImplFromJson(json);

  /// ユーザーID
  @override
  final String userId;

  /// 表示名
  @override
  final String displayName;

  /// 出発地点（例: 東京駅、新宿など）
  @override
  final String? departurePoint;

  /// 手動追加フラグ（セッション外のメンバー）
  @override
  @JsonKey()
  final bool isManual;

  /// 個別リンクID（手動メンバー用）
  @override
  final String? personalLinkId;

  /// 参加日時
  @override
  final DateTime? joinedAt;

  @override
  String toString() {
    return 'TripMember(userId: $userId, displayName: $displayName, departurePoint: $departurePoint, isManual: $isManual, personalLinkId: $personalLinkId, joinedAt: $joinedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TripMemberImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.departurePoint, departurePoint) ||
                other.departurePoint == departurePoint) &&
            (identical(other.isManual, isManual) ||
                other.isManual == isManual) &&
            (identical(other.personalLinkId, personalLinkId) ||
                other.personalLinkId == personalLinkId) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    displayName,
    departurePoint,
    isManual,
    personalLinkId,
    joinedAt,
  );

  /// Create a copy of TripMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TripMemberImplCopyWith<_$TripMemberImpl> get copyWith =>
      __$$TripMemberImplCopyWithImpl<_$TripMemberImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TripMemberImplToJson(this);
  }
}

abstract class _TripMember implements TripMember {
  const factory _TripMember({
    required final String userId,
    required final String displayName,
    final String? departurePoint,
    final bool isManual,
    final String? personalLinkId,
    final DateTime? joinedAt,
  }) = _$TripMemberImpl;

  factory _TripMember.fromJson(Map<String, dynamic> json) =
      _$TripMemberImpl.fromJson;

  /// ユーザーID
  @override
  String get userId;

  /// 表示名
  @override
  String get displayName;

  /// 出発地点（例: 東京駅、新宿など）
  @override
  String? get departurePoint;

  /// 手動追加フラグ（セッション外のメンバー）
  @override
  bool get isManual;

  /// 個別リンクID（手動メンバー用）
  @override
  String? get personalLinkId;

  /// 参加日時
  @override
  DateTime? get joinedAt;

  /// Create a copy of TripMember
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TripMemberImplCopyWith<_$TripMemberImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
