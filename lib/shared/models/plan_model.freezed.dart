// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PlanItem _$PlanItemFromJson(Map<String, dynamic> json) {
  return _PlanItem.fromJson(json);
}

/// @nodoc
mixin _$PlanItem {
  String get id => throw _privateConstructorUsedError;
  int get day => throw _privateConstructorUsedError;
  String get time => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  int get durationMinutes => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;

  /// 位置の精度半径（メートル）— AIジオコーディングの確信度
  double? get locationRadius => throw _privateConstructorUsedError;

  /// 予約URL
  String? get bookingUrl => throw _privateConstructorUsedError;

  /// 予約メモ（確認番号、予約名など）
  String? get bookingNote => throw _privateConstructorUsedError;

  /// 予約済みフラグ
  bool get isBooked => throw _privateConstructorUsedError;

  /// 予約画像URL（スクリーンショットなど）
  String? get bookingImageUrl => throw _privateConstructorUsedError;

  /// Serializes this PlanItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanItemCopyWith<PlanItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanItemCopyWith<$Res> {
  factory $PlanItemCopyWith(PlanItem value, $Res Function(PlanItem) then) =
      _$PlanItemCopyWithImpl<$Res, PlanItem>;
  @useResult
  $Res call({
    String id,
    int day,
    String time,
    String location,
    String? notes,
    int durationMinutes,
    double? latitude,
    double? longitude,
    double? locationRadius,
    String? bookingUrl,
    String? bookingNote,
    bool isBooked,
    String? bookingImageUrl,
  });
}

/// @nodoc
class _$PlanItemCopyWithImpl<$Res, $Val extends PlanItem>
    implements $PlanItemCopyWith<$Res> {
  _$PlanItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? day = null,
    Object? time = null,
    Object? location = null,
    Object? notes = freezed,
    Object? durationMinutes = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? locationRadius = freezed,
    Object? bookingUrl = freezed,
    Object? bookingNote = freezed,
    Object? isBooked = null,
    Object? bookingImageUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            day:
                null == day
                    ? _value.day
                    : day // ignore: cast_nullable_to_non_nullable
                        as int,
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
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
            durationMinutes:
                null == durationMinutes
                    ? _value.durationMinutes
                    : durationMinutes // ignore: cast_nullable_to_non_nullable
                        as int,
            latitude:
                freezed == latitude
                    ? _value.latitude
                    : latitude // ignore: cast_nullable_to_non_nullable
                        as double?,
            longitude:
                freezed == longitude
                    ? _value.longitude
                    : longitude // ignore: cast_nullable_to_non_nullable
                        as double?,
            locationRadius:
                freezed == locationRadius
                    ? _value.locationRadius
                    : locationRadius // ignore: cast_nullable_to_non_nullable
                        as double?,
            bookingUrl:
                freezed == bookingUrl
                    ? _value.bookingUrl
                    : bookingUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            bookingNote:
                freezed == bookingNote
                    ? _value.bookingNote
                    : bookingNote // ignore: cast_nullable_to_non_nullable
                        as String?,
            isBooked:
                null == isBooked
                    ? _value.isBooked
                    : isBooked // ignore: cast_nullable_to_non_nullable
                        as bool,
            bookingImageUrl:
                freezed == bookingImageUrl
                    ? _value.bookingImageUrl
                    : bookingImageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlanItemImplCopyWith<$Res>
    implements $PlanItemCopyWith<$Res> {
  factory _$$PlanItemImplCopyWith(
    _$PlanItemImpl value,
    $Res Function(_$PlanItemImpl) then,
  ) = __$$PlanItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    int day,
    String time,
    String location,
    String? notes,
    int durationMinutes,
    double? latitude,
    double? longitude,
    double? locationRadius,
    String? bookingUrl,
    String? bookingNote,
    bool isBooked,
    String? bookingImageUrl,
  });
}

/// @nodoc
class __$$PlanItemImplCopyWithImpl<$Res>
    extends _$PlanItemCopyWithImpl<$Res, _$PlanItemImpl>
    implements _$$PlanItemImplCopyWith<$Res> {
  __$$PlanItemImplCopyWithImpl(
    _$PlanItemImpl _value,
    $Res Function(_$PlanItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? day = null,
    Object? time = null,
    Object? location = null,
    Object? notes = freezed,
    Object? durationMinutes = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? locationRadius = freezed,
    Object? bookingUrl = freezed,
    Object? bookingNote = freezed,
    Object? isBooked = null,
    Object? bookingImageUrl = freezed,
  }) {
    return _then(
      _$PlanItemImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        day:
            null == day
                ? _value.day
                : day // ignore: cast_nullable_to_non_nullable
                    as int,
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
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
        durationMinutes:
            null == durationMinutes
                ? _value.durationMinutes
                : durationMinutes // ignore: cast_nullable_to_non_nullable
                    as int,
        latitude:
            freezed == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                    as double?,
        longitude:
            freezed == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                    as double?,
        locationRadius:
            freezed == locationRadius
                ? _value.locationRadius
                : locationRadius // ignore: cast_nullable_to_non_nullable
                    as double?,
        bookingUrl:
            freezed == bookingUrl
                ? _value.bookingUrl
                : bookingUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        bookingNote:
            freezed == bookingNote
                ? _value.bookingNote
                : bookingNote // ignore: cast_nullable_to_non_nullable
                    as String?,
        isBooked:
            null == isBooked
                ? _value.isBooked
                : isBooked // ignore: cast_nullable_to_non_nullable
                    as bool,
        bookingImageUrl:
            freezed == bookingImageUrl
                ? _value.bookingImageUrl
                : bookingImageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlanItemImpl implements _PlanItem {
  const _$PlanItemImpl({
    this.id = '',
    this.day = 1,
    required this.time,
    required this.location,
    this.notes,
    this.durationMinutes = 60,
    this.latitude,
    this.longitude,
    this.locationRadius,
    this.bookingUrl,
    this.bookingNote,
    this.isBooked = false,
    this.bookingImageUrl,
  });

  factory _$PlanItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanItemImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final int day;
  @override
  final String time;
  @override
  final String location;
  @override
  final String? notes;
  @override
  @JsonKey()
  final int durationMinutes;
  @override
  final double? latitude;
  @override
  final double? longitude;

  /// 位置の精度半径（メートル）— AIジオコーディングの確信度
  @override
  final double? locationRadius;

  /// 予約URL
  @override
  final String? bookingUrl;

  /// 予約メモ（確認番号、予約名など）
  @override
  final String? bookingNote;

  /// 予約済みフラグ
  @override
  @JsonKey()
  final bool isBooked;

  /// 予約画像URL（スクリーンショットなど）
  @override
  final String? bookingImageUrl;

  @override
  String toString() {
    return 'PlanItem(id: $id, day: $day, time: $time, location: $location, notes: $notes, durationMinutes: $durationMinutes, latitude: $latitude, longitude: $longitude, locationRadius: $locationRadius, bookingUrl: $bookingUrl, bookingNote: $bookingNote, isBooked: $isBooked, bookingImageUrl: $bookingImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.day, day) || other.day == day) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.durationMinutes, durationMinutes) ||
                other.durationMinutes == durationMinutes) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.locationRadius, locationRadius) ||
                other.locationRadius == locationRadius) &&
            (identical(other.bookingUrl, bookingUrl) ||
                other.bookingUrl == bookingUrl) &&
            (identical(other.bookingNote, bookingNote) ||
                other.bookingNote == bookingNote) &&
            (identical(other.isBooked, isBooked) ||
                other.isBooked == isBooked) &&
            (identical(other.bookingImageUrl, bookingImageUrl) ||
                other.bookingImageUrl == bookingImageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    day,
    time,
    location,
    notes,
    durationMinutes,
    latitude,
    longitude,
    locationRadius,
    bookingUrl,
    bookingNote,
    isBooked,
    bookingImageUrl,
  );

  /// Create a copy of PlanItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanItemImplCopyWith<_$PlanItemImpl> get copyWith =>
      __$$PlanItemImplCopyWithImpl<_$PlanItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanItemImplToJson(this);
  }
}

abstract class _PlanItem implements PlanItem {
  const factory _PlanItem({
    final String id,
    final int day,
    required final String time,
    required final String location,
    final String? notes,
    final int durationMinutes,
    final double? latitude,
    final double? longitude,
    final double? locationRadius,
    final String? bookingUrl,
    final String? bookingNote,
    final bool isBooked,
    final String? bookingImageUrl,
  }) = _$PlanItemImpl;

  factory _PlanItem.fromJson(Map<String, dynamic> json) =
      _$PlanItemImpl.fromJson;

  @override
  String get id;
  @override
  int get day;
  @override
  String get time;
  @override
  String get location;
  @override
  String? get notes;
  @override
  int get durationMinutes;
  @override
  double? get latitude;
  @override
  double? get longitude;

  /// 位置の精度半径（メートル）— AIジオコーディングの確信度
  @override
  double? get locationRadius;

  /// 予約URL
  @override
  String? get bookingUrl;

  /// 予約メモ（確認番号、予約名など）
  @override
  String? get bookingNote;

  /// 予約済みフラグ
  @override
  bool get isBooked;

  /// 予約画像URL（スクリーンショットなど）
  @override
  String? get bookingImageUrl;

  /// Create a copy of PlanItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanItemImplCopyWith<_$PlanItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlanModel _$PlanModelFromJson(Map<String, dynamic> json) {
  return _PlanModel.fromJson(json);
}

/// @nodoc
mixin _$PlanModel {
  String get id => throw _privateConstructorUsedError;
  String get tripId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  List<PlanItem> get items => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// 現在編集中のユーザーID（共同編集ロック用）
  String? get editingBy => throw _privateConstructorUsedError;

  /// 最後に編集したユーザー名
  String? get lastEditedByName => throw _privateConstructorUsedError;

  /// Serializes this PlanModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanModelCopyWith<PlanModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanModelCopyWith<$Res> {
  factory $PlanModelCopyWith(PlanModel value, $Res Function(PlanModel) then) =
      _$PlanModelCopyWithImpl<$Res, PlanModel>;
  @useResult
  $Res call({
    String id,
    String tripId,
    String title,
    String? description,
    List<PlanItem> items,
    DateTime createdAt,
    DateTime? updatedAt,
    String? editingBy,
    String? lastEditedByName,
  });
}

/// @nodoc
class _$PlanModelCopyWithImpl<$Res, $Val extends PlanModel>
    implements $PlanModelCopyWith<$Res> {
  _$PlanModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tripId = null,
    Object? title = null,
    Object? description = freezed,
    Object? items = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? editingBy = freezed,
    Object? lastEditedByName = freezed,
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
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            items:
                null == items
                    ? _value.items
                    : items // ignore: cast_nullable_to_non_nullable
                        as List<PlanItem>,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            editingBy:
                freezed == editingBy
                    ? _value.editingBy
                    : editingBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            lastEditedByName:
                freezed == lastEditedByName
                    ? _value.lastEditedByName
                    : lastEditedByName // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlanModelImplCopyWith<$Res>
    implements $PlanModelCopyWith<$Res> {
  factory _$$PlanModelImplCopyWith(
    _$PlanModelImpl value,
    $Res Function(_$PlanModelImpl) then,
  ) = __$$PlanModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String tripId,
    String title,
    String? description,
    List<PlanItem> items,
    DateTime createdAt,
    DateTime? updatedAt,
    String? editingBy,
    String? lastEditedByName,
  });
}

/// @nodoc
class __$$PlanModelImplCopyWithImpl<$Res>
    extends _$PlanModelCopyWithImpl<$Res, _$PlanModelImpl>
    implements _$$PlanModelImplCopyWith<$Res> {
  __$$PlanModelImplCopyWithImpl(
    _$PlanModelImpl _value,
    $Res Function(_$PlanModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tripId = null,
    Object? title = null,
    Object? description = freezed,
    Object? items = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? editingBy = freezed,
    Object? lastEditedByName = freezed,
  }) {
    return _then(
      _$PlanModelImpl(
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
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        items:
            null == items
                ? _value._items
                : items // ignore: cast_nullable_to_non_nullable
                    as List<PlanItem>,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        editingBy:
            freezed == editingBy
                ? _value.editingBy
                : editingBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        lastEditedByName:
            freezed == lastEditedByName
                ? _value.lastEditedByName
                : lastEditedByName // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlanModelImpl implements _PlanModel {
  const _$PlanModelImpl({
    required this.id,
    required this.tripId,
    required this.title,
    this.description,
    final List<PlanItem> items = const [],
    required this.createdAt,
    this.updatedAt,
    this.editingBy,
    this.lastEditedByName,
  }) : _items = items;

  factory _$PlanModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanModelImplFromJson(json);

  @override
  final String id;
  @override
  final String tripId;
  @override
  final String title;
  @override
  final String? description;
  final List<PlanItem> _items;
  @override
  @JsonKey()
  List<PlanItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  /// 現在編集中のユーザーID（共同編集ロック用）
  @override
  final String? editingBy;

  /// 最後に編集したユーザー名
  @override
  final String? lastEditedByName;

  @override
  String toString() {
    return 'PlanModel(id: $id, tripId: $tripId, title: $title, description: $description, items: $items, createdAt: $createdAt, updatedAt: $updatedAt, editingBy: $editingBy, lastEditedByName: $lastEditedByName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tripId, tripId) || other.tripId == tripId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.editingBy, editingBy) ||
                other.editingBy == editingBy) &&
            (identical(other.lastEditedByName, lastEditedByName) ||
                other.lastEditedByName == lastEditedByName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tripId,
    title,
    description,
    const DeepCollectionEquality().hash(_items),
    createdAt,
    updatedAt,
    editingBy,
    lastEditedByName,
  );

  /// Create a copy of PlanModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanModelImplCopyWith<_$PlanModelImpl> get copyWith =>
      __$$PlanModelImplCopyWithImpl<_$PlanModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanModelImplToJson(this);
  }
}

abstract class _PlanModel implements PlanModel {
  const factory _PlanModel({
    required final String id,
    required final String tripId,
    required final String title,
    final String? description,
    final List<PlanItem> items,
    required final DateTime createdAt,
    final DateTime? updatedAt,
    final String? editingBy,
    final String? lastEditedByName,
  }) = _$PlanModelImpl;

  factory _PlanModel.fromJson(Map<String, dynamic> json) =
      _$PlanModelImpl.fromJson;

  @override
  String get id;
  @override
  String get tripId;
  @override
  String get title;
  @override
  String? get description;
  @override
  List<PlanItem> get items;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// 現在編集中のユーザーID（共同編集ロック用）
  @override
  String? get editingBy;

  /// 最後に編集したユーザー名
  @override
  String? get lastEditedByName;

  /// Create a copy of PlanModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanModelImplCopyWith<_$PlanModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
