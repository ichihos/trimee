// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'expense_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ExpenseItem _$ExpenseItemFromJson(Map<String, dynamic> json) {
  return _ExpenseItem.fromJson(json);
}

/// @nodoc
mixin _$ExpenseItem {
  String get id => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  String get paidBy => throw _privateConstructorUsedError;
  List<String> get splitWith => throw _privateConstructorUsedError;
  ExpenseCategory get category => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this ExpenseItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExpenseItemCopyWith<ExpenseItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExpenseItemCopyWith<$Res> {
  factory $ExpenseItemCopyWith(
    ExpenseItem value,
    $Res Function(ExpenseItem) then,
  ) = _$ExpenseItemCopyWithImpl<$Res, ExpenseItem>;
  @useResult
  $Res call({
    String id,
    String description,
    int amount,
    String paidBy,
    List<String> splitWith,
    ExpenseCategory category,
    DateTime createdAt,
  });
}

/// @nodoc
class _$ExpenseItemCopyWithImpl<$Res, $Val extends ExpenseItem>
    implements $ExpenseItemCopyWith<$Res> {
  _$ExpenseItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? description = null,
    Object? amount = null,
    Object? paidBy = null,
    Object? splitWith = null,
    Object? category = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                null == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String,
            amount:
                null == amount
                    ? _value.amount
                    : amount // ignore: cast_nullable_to_non_nullable
                        as int,
            paidBy:
                null == paidBy
                    ? _value.paidBy
                    : paidBy // ignore: cast_nullable_to_non_nullable
                        as String,
            splitWith:
                null == splitWith
                    ? _value.splitWith
                    : splitWith // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            category:
                null == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as ExpenseCategory,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExpenseItemImplCopyWith<$Res>
    implements $ExpenseItemCopyWith<$Res> {
  factory _$$ExpenseItemImplCopyWith(
    _$ExpenseItemImpl value,
    $Res Function(_$ExpenseItemImpl) then,
  ) = __$$ExpenseItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String description,
    int amount,
    String paidBy,
    List<String> splitWith,
    ExpenseCategory category,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$ExpenseItemImplCopyWithImpl<$Res>
    extends _$ExpenseItemCopyWithImpl<$Res, _$ExpenseItemImpl>
    implements _$$ExpenseItemImplCopyWith<$Res> {
  __$$ExpenseItemImplCopyWithImpl(
    _$ExpenseItemImpl _value,
    $Res Function(_$ExpenseItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? description = null,
    Object? amount = null,
    Object? paidBy = null,
    Object? splitWith = null,
    Object? category = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$ExpenseItemImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String,
        amount:
            null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                    as int,
        paidBy:
            null == paidBy
                ? _value.paidBy
                : paidBy // ignore: cast_nullable_to_non_nullable
                    as String,
        splitWith:
            null == splitWith
                ? _value._splitWith
                : splitWith // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        category:
            null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as ExpenseCategory,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ExpenseItemImpl implements _ExpenseItem {
  const _$ExpenseItemImpl({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    final List<String> splitWith = const [],
    required this.category,
    required this.createdAt,
  }) : _splitWith = splitWith;

  factory _$ExpenseItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExpenseItemImplFromJson(json);

  @override
  final String id;
  @override
  final String description;
  @override
  final int amount;
  @override
  final String paidBy;
  final List<String> _splitWith;
  @override
  @JsonKey()
  List<String> get splitWith {
    if (_splitWith is EqualUnmodifiableListView) return _splitWith;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_splitWith);
  }

  @override
  final ExpenseCategory category;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'ExpenseItem(id: $id, description: $description, amount: $amount, paidBy: $paidBy, splitWith: $splitWith, category: $category, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExpenseItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.paidBy, paidBy) || other.paidBy == paidBy) &&
            const DeepCollectionEquality().equals(
              other._splitWith,
              _splitWith,
            ) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    description,
    amount,
    paidBy,
    const DeepCollectionEquality().hash(_splitWith),
    category,
    createdAt,
  );

  /// Create a copy of ExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExpenseItemImplCopyWith<_$ExpenseItemImpl> get copyWith =>
      __$$ExpenseItemImplCopyWithImpl<_$ExpenseItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExpenseItemImplToJson(this);
  }
}

abstract class _ExpenseItem implements ExpenseItem {
  const factory _ExpenseItem({
    required final String id,
    required final String description,
    required final int amount,
    required final String paidBy,
    final List<String> splitWith,
    required final ExpenseCategory category,
    required final DateTime createdAt,
  }) = _$ExpenseItemImpl;

  factory _ExpenseItem.fromJson(Map<String, dynamic> json) =
      _$ExpenseItemImpl.fromJson;

  @override
  String get id;
  @override
  String get description;
  @override
  int get amount;
  @override
  String get paidBy;
  @override
  List<String> get splitWith;
  @override
  ExpenseCategory get category;
  @override
  DateTime get createdAt;

  /// Create a copy of ExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExpenseItemImplCopyWith<_$ExpenseItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SettlementItem _$SettlementItemFromJson(Map<String, dynamic> json) {
  return _SettlementItem.fromJson(json);
}

/// @nodoc
mixin _$SettlementItem {
  String get fromUserId => throw _privateConstructorUsedError;
  String get toUserId => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;

  /// Serializes this SettlementItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SettlementItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SettlementItemCopyWith<SettlementItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SettlementItemCopyWith<$Res> {
  factory $SettlementItemCopyWith(
    SettlementItem value,
    $Res Function(SettlementItem) then,
  ) = _$SettlementItemCopyWithImpl<$Res, SettlementItem>;
  @useResult
  $Res call({String fromUserId, String toUserId, int amount});
}

/// @nodoc
class _$SettlementItemCopyWithImpl<$Res, $Val extends SettlementItem>
    implements $SettlementItemCopyWith<$Res> {
  _$SettlementItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SettlementItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fromUserId = null,
    Object? toUserId = null,
    Object? amount = null,
  }) {
    return _then(
      _value.copyWith(
            fromUserId:
                null == fromUserId
                    ? _value.fromUserId
                    : fromUserId // ignore: cast_nullable_to_non_nullable
                        as String,
            toUserId:
                null == toUserId
                    ? _value.toUserId
                    : toUserId // ignore: cast_nullable_to_non_nullable
                        as String,
            amount:
                null == amount
                    ? _value.amount
                    : amount // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SettlementItemImplCopyWith<$Res>
    implements $SettlementItemCopyWith<$Res> {
  factory _$$SettlementItemImplCopyWith(
    _$SettlementItemImpl value,
    $Res Function(_$SettlementItemImpl) then,
  ) = __$$SettlementItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String fromUserId, String toUserId, int amount});
}

/// @nodoc
class __$$SettlementItemImplCopyWithImpl<$Res>
    extends _$SettlementItemCopyWithImpl<$Res, _$SettlementItemImpl>
    implements _$$SettlementItemImplCopyWith<$Res> {
  __$$SettlementItemImplCopyWithImpl(
    _$SettlementItemImpl _value,
    $Res Function(_$SettlementItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SettlementItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fromUserId = null,
    Object? toUserId = null,
    Object? amount = null,
  }) {
    return _then(
      _$SettlementItemImpl(
        fromUserId:
            null == fromUserId
                ? _value.fromUserId
                : fromUserId // ignore: cast_nullable_to_non_nullable
                    as String,
        toUserId:
            null == toUserId
                ? _value.toUserId
                : toUserId // ignore: cast_nullable_to_non_nullable
                    as String,
        amount:
            null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SettlementItemImpl implements _SettlementItem {
  const _$SettlementItemImpl({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  factory _$SettlementItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$SettlementItemImplFromJson(json);

  @override
  final String fromUserId;
  @override
  final String toUserId;
  @override
  final int amount;

  @override
  String toString() {
    return 'SettlementItem(fromUserId: $fromUserId, toUserId: $toUserId, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SettlementItemImpl &&
            (identical(other.fromUserId, fromUserId) ||
                other.fromUserId == fromUserId) &&
            (identical(other.toUserId, toUserId) ||
                other.toUserId == toUserId) &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, fromUserId, toUserId, amount);

  /// Create a copy of SettlementItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SettlementItemImplCopyWith<_$SettlementItemImpl> get copyWith =>
      __$$SettlementItemImplCopyWithImpl<_$SettlementItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SettlementItemImplToJson(this);
  }
}

abstract class _SettlementItem implements SettlementItem {
  const factory _SettlementItem({
    required final String fromUserId,
    required final String toUserId,
    required final int amount,
  }) = _$SettlementItemImpl;

  factory _SettlementItem.fromJson(Map<String, dynamic> json) =
      _$SettlementItemImpl.fromJson;

  @override
  String get fromUserId;
  @override
  String get toUserId;
  @override
  int get amount;

  /// Create a copy of SettlementItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SettlementItemImplCopyWith<_$SettlementItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
