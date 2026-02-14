import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/expense_model.dart';

const _uuid = Uuid();

/// 旅行ごとの支出リストを管理するプロバイダー
final expensesProvider =
    StateNotifierProvider.family<ExpensesNotifier, List<ExpenseItem>, String>((
      ref,
      tripId,
    ) {
      return ExpensesNotifier();
    });

class ExpensesNotifier extends StateNotifier<List<ExpenseItem>> {
  ExpensesNotifier() : super([]);

  /// 支出を追加
  void addExpense({
    required String description,
    required int amount,
    required String paidBy,
    required List<String> splitWith,
    required ExpenseCategory category,
  }) {
    final expense = ExpenseItem(
      id: _uuid.v4(),
      description: description,
      amount: amount,
      paidBy: paidBy,
      splitWith: splitWith,
      category: category,
      createdAt: DateTime.now(),
    );
    state = [...state, expense];
  }

  /// 支出を削除
  void removeExpense(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  /// 支出を更新
  void updateExpense(ExpenseItem expense) {
    state = state.map((e) => e.id == expense.id ? expense : e).toList();
  }
}

/// 精算結果を計算するプロバイダー
final settlementsProvider = Provider.family<List<SettlementItem>, ({String tripId, List<String> members})>((
  ref,
  params,
) {
  final expenses = ref.watch(expensesProvider(params.tripId));
  return ExpenseCalculator.calculateSettlements(expenses, params.members);
});

/// 総額を計算するプロバイダー
final totalExpenseProvider = Provider.family<int, String>((ref, tripId) {
  final expenses = ref.watch(expensesProvider(tripId));
  return ExpenseCalculator.calculateTotal(expenses);
});
