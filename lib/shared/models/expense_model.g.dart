// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExpenseItemImpl _$$ExpenseItemImplFromJson(Map<String, dynamic> json) =>
    _$ExpenseItemImpl(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toInt(),
      paidBy: json['paidBy'] as String,
      splitWith:
          (json['splitWith'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      category: $enumDecode(_$ExpenseCategoryEnumMap, json['category']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ExpenseItemImplToJson(_$ExpenseItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'description': instance.description,
      'amount': instance.amount,
      'paidBy': instance.paidBy,
      'splitWith': instance.splitWith,
      'category': _$ExpenseCategoryEnumMap[instance.category]!,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$ExpenseCategoryEnumMap = {
  ExpenseCategory.accommodation: 'accommodation',
  ExpenseCategory.transportation: 'transportation',
  ExpenseCategory.food: 'food',
  ExpenseCategory.activity: 'activity',
  ExpenseCategory.other: 'other',
};

_$SettlementItemImpl _$$SettlementItemImplFromJson(Map<String, dynamic> json) =>
    _$SettlementItemImpl(
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      amount: (json['amount'] as num).toInt(),
    );

Map<String, dynamic> _$$SettlementItemImplToJson(
  _$SettlementItemImpl instance,
) => <String, dynamic>{
  'fromUserId': instance.fromUserId,
  'toUserId': instance.toUserId,
  'amount': instance.amount,
};
