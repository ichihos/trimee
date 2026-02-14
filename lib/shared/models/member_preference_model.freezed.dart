// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'member_preference_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MemberPreferenceModel _$MemberPreferenceModelFromJson(
  Map<String, dynamic> json,
) {
  return _MemberPreferenceModel.fromJson(json);
}

/// @nodoc
mixin _$MemberPreferenceModel {
  String get id => throw _privateConstructorUsedError;
  String get tripId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get notes => throw _privateConstructorUsedError;
  List<String> get mustVisit => throw _privateConstructorUsedError;
  List<String> get avoid => throw _privateConstructorUsedError;

  /// Serializes this MemberPreferenceModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MemberPreferenceModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MemberPreferenceModelCopyWith<MemberPreferenceModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MemberPreferenceModelCopyWith<$Res> {
  factory $MemberPreferenceModelCopyWith(
    MemberPreferenceModel value,
    $Res Function(MemberPreferenceModel) then,
  ) = _$MemberPreferenceModelCopyWithImpl<$Res, MemberPreferenceModel>;
  @useResult
  $Res call({
    String id,
    String tripId,
    String userId,
    String notes,
    List<String> mustVisit,
    List<String> avoid,
  });
}

/// @nodoc
class _$MemberPreferenceModelCopyWithImpl<
  $Res,
  $Val extends MemberPreferenceModel
>
    implements $MemberPreferenceModelCopyWith<$Res> {
  _$MemberPreferenceModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MemberPreferenceModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tripId = null,
    Object? userId = null,
    Object? notes = null,
    Object? mustVisit = null,
    Object? avoid = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            tripId:
                null == tripId
                    ? _value.tripId
                    : tripId // ignore: cast_nullable_to_non_nullable
                        as String,
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            notes:
                null == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String,
            mustVisit:
                null == mustVisit
                    ? _value.mustVisit
                    : mustVisit // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            avoid:
                null == avoid
                    ? _value.avoid
                    : avoid // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MemberPreferenceModelImplCopyWith<$Res>
    implements $MemberPreferenceModelCopyWith<$Res> {
  factory _$$MemberPreferenceModelImplCopyWith(
    _$MemberPreferenceModelImpl value,
    $Res Function(_$MemberPreferenceModelImpl) then,
  ) = __$$MemberPreferenceModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String tripId,
    String userId,
    String notes,
    List<String> mustVisit,
    List<String> avoid,
  });
}

/// @nodoc
class __$$MemberPreferenceModelImplCopyWithImpl<$Res>
    extends
        _$MemberPreferenceModelCopyWithImpl<$Res, _$MemberPreferenceModelImpl>
    implements _$$MemberPreferenceModelImplCopyWith<$Res> {
  __$$MemberPreferenceModelImplCopyWithImpl(
    _$MemberPreferenceModelImpl _value,
    $Res Function(_$MemberPreferenceModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MemberPreferenceModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tripId = null,
    Object? userId = null,
    Object? notes = null,
    Object? mustVisit = null,
    Object? avoid = null,
  }) {
    return _then(
      _$MemberPreferenceModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        tripId:
            null == tripId
                ? _value.tripId
                : tripId // ignore: cast_nullable_to_non_nullable
                    as String,
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        notes:
            null == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String,
        mustVisit:
            null == mustVisit
                ? _value._mustVisit
                : mustVisit // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        avoid:
            null == avoid
                ? _value._avoid
                : avoid // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MemberPreferenceModelImpl implements _MemberPreferenceModel {
  const _$MemberPreferenceModelImpl({
    required this.id,
    required this.tripId,
    required this.userId,
    this.notes = '',
    final List<String> mustVisit = const [],
    final List<String> avoid = const [],
  }) : _mustVisit = mustVisit,
       _avoid = avoid;

  factory _$MemberPreferenceModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$MemberPreferenceModelImplFromJson(json);

  @override
  final String id;
  @override
  final String tripId;
  @override
  final String userId;
  @override
  @JsonKey()
  final String notes;
  final List<String> _mustVisit;
  @override
  @JsonKey()
  List<String> get mustVisit {
    if (_mustVisit is EqualUnmodifiableListView) return _mustVisit;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mustVisit);
  }

  final List<String> _avoid;
  @override
  @JsonKey()
  List<String> get avoid {
    if (_avoid is EqualUnmodifiableListView) return _avoid;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_avoid);
  }

  @override
  String toString() {
    return 'MemberPreferenceModel(id: $id, tripId: $tripId, userId: $userId, notes: $notes, mustVisit: $mustVisit, avoid: $avoid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MemberPreferenceModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tripId, tripId) || other.tripId == tripId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality().equals(
              other._mustVisit,
              _mustVisit,
            ) &&
            const DeepCollectionEquality().equals(other._avoid, _avoid));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tripId,
    userId,
    notes,
    const DeepCollectionEquality().hash(_mustVisit),
    const DeepCollectionEquality().hash(_avoid),
  );

  /// Create a copy of MemberPreferenceModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MemberPreferenceModelImplCopyWith<_$MemberPreferenceModelImpl>
  get copyWith =>
      __$$MemberPreferenceModelImplCopyWithImpl<_$MemberPreferenceModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MemberPreferenceModelImplToJson(this);
  }
}

abstract class _MemberPreferenceModel implements MemberPreferenceModel {
  const factory _MemberPreferenceModel({
    required final String id,
    required final String tripId,
    required final String userId,
    final String notes,
    final List<String> mustVisit,
    final List<String> avoid,
  }) = _$MemberPreferenceModelImpl;

  factory _MemberPreferenceModel.fromJson(Map<String, dynamic> json) =
      _$MemberPreferenceModelImpl.fromJson;

  @override
  String get id;
  @override
  String get tripId;
  @override
  String get userId;
  @override
  String get notes;
  @override
  List<String> get mustVisit;
  @override
  List<String> get avoid;

  /// Create a copy of MemberPreferenceModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MemberPreferenceModelImplCopyWith<_$MemberPreferenceModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
