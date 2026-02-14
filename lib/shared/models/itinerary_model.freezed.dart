// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'itinerary_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ItineraryItem _$ItineraryItemFromJson(Map<String, dynamic> json) {
  return _ItineraryItem.fromJson(json);
}

/// @nodoc
mixin _$ItineraryItem {
  String get time => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String? get activity => throw _privateConstructorUsedError;
  int get durationMinutes => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  Map<String, bool> get votes => throw _privateConstructorUsedError;

  /// Serializes this ItineraryItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ItineraryItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ItineraryItemCopyWith<ItineraryItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ItineraryItemCopyWith<$Res> {
  factory $ItineraryItemCopyWith(
    ItineraryItem value,
    $Res Function(ItineraryItem) then,
  ) = _$ItineraryItemCopyWithImpl<$Res, ItineraryItem>;
  @useResult
  $Res call({
    String time,
    String location,
    String? activity,
    int durationMinutes,
    String? notes,
    Map<String, bool> votes,
  });
}

/// @nodoc
class _$ItineraryItemCopyWithImpl<$Res, $Val extends ItineraryItem>
    implements $ItineraryItemCopyWith<$Res> {
  _$ItineraryItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ItineraryItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = null,
    Object? location = null,
    Object? activity = freezed,
    Object? durationMinutes = null,
    Object? notes = freezed,
    Object? votes = null,
  }) {
    return _then(
      _value.copyWith(
            time:
                null == time
                    ? _value.time
                    : time // ignore: cast_nullable_to_non_nullable
                        as String,
            location:
                null == location
                    ? _value.location
                    : location // ignore: cast_nullable_to_non_nullable
                        as String,
            activity:
                freezed == activity
                    ? _value.activity
                    : activity // ignore: cast_nullable_to_non_nullable
                        as String?,
            durationMinutes:
                null == durationMinutes
                    ? _value.durationMinutes
                    : durationMinutes // ignore: cast_nullable_to_non_nullable
                        as int,
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
            votes:
                null == votes
                    ? _value.votes
                    : votes // ignore: cast_nullable_to_non_nullable
                        as Map<String, bool>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ItineraryItemImplCopyWith<$Res>
    implements $ItineraryItemCopyWith<$Res> {
  factory _$$ItineraryItemImplCopyWith(
    _$ItineraryItemImpl value,
    $Res Function(_$ItineraryItemImpl) then,
  ) = __$$ItineraryItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String time,
    String location,
    String? activity,
    int durationMinutes,
    String? notes,
    Map<String, bool> votes,
  });
}

/// @nodoc
class __$$ItineraryItemImplCopyWithImpl<$Res>
    extends _$ItineraryItemCopyWithImpl<$Res, _$ItineraryItemImpl>
    implements _$$ItineraryItemImplCopyWith<$Res> {
  __$$ItineraryItemImplCopyWithImpl(
    _$ItineraryItemImpl _value,
    $Res Function(_$ItineraryItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ItineraryItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = null,
    Object? location = null,
    Object? activity = freezed,
    Object? durationMinutes = null,
    Object? notes = freezed,
    Object? votes = null,
  }) {
    return _then(
      _$ItineraryItemImpl(
        time:
            null == time
                ? _value.time
                : time // ignore: cast_nullable_to_non_nullable
                    as String,
        location:
            null == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                    as String,
        activity:
            freezed == activity
                ? _value.activity
                : activity // ignore: cast_nullable_to_non_nullable
                    as String?,
        durationMinutes:
            null == durationMinutes
                ? _value.durationMinutes
                : durationMinutes // ignore: cast_nullable_to_non_nullable
                    as int,
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
        votes:
            null == votes
                ? _value._votes
                : votes // ignore: cast_nullable_to_non_nullable
                    as Map<String, bool>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ItineraryItemImpl implements _ItineraryItem {
  const _$ItineraryItemImpl({
    required this.time,
    required this.location,
    this.activity,
    this.durationMinutes = 60,
    this.notes,
    final Map<String, bool> votes = const {},
  }) : _votes = votes;

  factory _$ItineraryItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ItineraryItemImplFromJson(json);

  @override
  final String time;
  @override
  final String location;
  @override
  final String? activity;
  @override
  @JsonKey()
  final int durationMinutes;
  @override
  final String? notes;
  final Map<String, bool> _votes;
  @override
  @JsonKey()
  Map<String, bool> get votes {
    if (_votes is EqualUnmodifiableMapView) return _votes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_votes);
  }

  @override
  String toString() {
    return 'ItineraryItem(time: $time, location: $location, activity: $activity, durationMinutes: $durationMinutes, notes: $notes, votes: $votes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ItineraryItemImpl &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.activity, activity) ||
                other.activity == activity) &&
            (identical(other.durationMinutes, durationMinutes) ||
                other.durationMinutes == durationMinutes) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality().equals(other._votes, _votes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    time,
    location,
    activity,
    durationMinutes,
    notes,
    const DeepCollectionEquality().hash(_votes),
  );

  /// Create a copy of ItineraryItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ItineraryItemImplCopyWith<_$ItineraryItemImpl> get copyWith =>
      __$$ItineraryItemImplCopyWithImpl<_$ItineraryItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ItineraryItemImplToJson(this);
  }
}

abstract class _ItineraryItem implements ItineraryItem {
  const factory _ItineraryItem({
    required final String time,
    required final String location,
    final String? activity,
    final int durationMinutes,
    final String? notes,
    final Map<String, bool> votes,
  }) = _$ItineraryItemImpl;

  factory _ItineraryItem.fromJson(Map<String, dynamic> json) =
      _$ItineraryItemImpl.fromJson;

  @override
  String get time;
  @override
  String get location;
  @override
  String? get activity;
  @override
  int get durationMinutes;
  @override
  String? get notes;
  @override
  Map<String, bool> get votes;

  /// Create a copy of ItineraryItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ItineraryItemImplCopyWith<_$ItineraryItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ItineraryModel _$ItineraryModelFromJson(Map<String, dynamic> json) {
  return _ItineraryModel.fromJson(json);
}

/// @nodoc
mixin _$ItineraryModel {
  String get id => throw _privateConstructorUsedError;
  String get tripId => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  List<ItineraryItem> get items => throw _privateConstructorUsedError;

  /// Serializes this ItineraryModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ItineraryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ItineraryModelCopyWith<ItineraryModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ItineraryModelCopyWith<$Res> {
  factory $ItineraryModelCopyWith(
    ItineraryModel value,
    $Res Function(ItineraryModel) then,
  ) = _$ItineraryModelCopyWithImpl<$Res, ItineraryModel>;
  @useResult
  $Res call({
    String id,
    String tripId,
    DateTime date,
    List<ItineraryItem> items,
  });
}

/// @nodoc
class _$ItineraryModelCopyWithImpl<$Res, $Val extends ItineraryModel>
    implements $ItineraryModelCopyWith<$Res> {
  _$ItineraryModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ItineraryModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tripId = null,
    Object? date = null,
    Object? items = null,
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
            date:
                null == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            items:
                null == items
                    ? _value.items
                    : items // ignore: cast_nullable_to_non_nullable
                        as List<ItineraryItem>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ItineraryModelImplCopyWith<$Res>
    implements $ItineraryModelCopyWith<$Res> {
  factory _$$ItineraryModelImplCopyWith(
    _$ItineraryModelImpl value,
    $Res Function(_$ItineraryModelImpl) then,
  ) = __$$ItineraryModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String tripId,
    DateTime date,
    List<ItineraryItem> items,
  });
}

/// @nodoc
class __$$ItineraryModelImplCopyWithImpl<$Res>
    extends _$ItineraryModelCopyWithImpl<$Res, _$ItineraryModelImpl>
    implements _$$ItineraryModelImplCopyWith<$Res> {
  __$$ItineraryModelImplCopyWithImpl(
    _$ItineraryModelImpl _value,
    $Res Function(_$ItineraryModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ItineraryModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tripId = null,
    Object? date = null,
    Object? items = null,
  }) {
    return _then(
      _$ItineraryModelImpl(
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
        date:
            null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        items:
            null == items
                ? _value._items
                : items // ignore: cast_nullable_to_non_nullable
                    as List<ItineraryItem>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ItineraryModelImpl implements _ItineraryModel {
  const _$ItineraryModelImpl({
    required this.id,
    required this.tripId,
    required this.date,
    final List<ItineraryItem> items = const [],
  }) : _items = items;

  factory _$ItineraryModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ItineraryModelImplFromJson(json);

  @override
  final String id;
  @override
  final String tripId;
  @override
  final DateTime date;
  final List<ItineraryItem> _items;
  @override
  @JsonKey()
  List<ItineraryItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  String toString() {
    return 'ItineraryModel(id: $id, tripId: $tripId, date: $date, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ItineraryModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tripId, tripId) || other.tripId == tripId) &&
            (identical(other.date, date) || other.date == date) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tripId,
    date,
    const DeepCollectionEquality().hash(_items),
  );

  /// Create a copy of ItineraryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ItineraryModelImplCopyWith<_$ItineraryModelImpl> get copyWith =>
      __$$ItineraryModelImplCopyWithImpl<_$ItineraryModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ItineraryModelImplToJson(this);
  }
}

abstract class _ItineraryModel implements ItineraryModel {
  const factory _ItineraryModel({
    required final String id,
    required final String tripId,
    required final DateTime date,
    final List<ItineraryItem> items,
  }) = _$ItineraryModelImpl;

  factory _ItineraryModel.fromJson(Map<String, dynamic> json) =
      _$ItineraryModelImpl.fromJson;

  @override
  String get id;
  @override
  String get tripId;
  @override
  DateTime get date;
  @override
  List<ItineraryItem> get items;

  /// Create a copy of ItineraryModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ItineraryModelImplCopyWith<_$ItineraryModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
