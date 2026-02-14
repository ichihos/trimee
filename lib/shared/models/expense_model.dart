import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense_model.freezed.dart';
part 'expense_model.g.dart';

/// 支出カテゴリ
enum ExpenseCategory {
  accommodation('宿泊', '🏨'),
  transportation('交通', '🚃'),
  food('食事', '🍽️'),
  activity('アクティビティ', '🎯'),
  other('その他', '📦');

  const ExpenseCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 支出アイテム
@freezed
class ExpenseItem with _$ExpenseItem {
  const factory ExpenseItem({
    required String id,
    required String description,
    required int amount,
    required String paidBy,
    @Default([]) List<String> splitWith,
    required ExpenseCategory category,
    required DateTime createdAt,
  }) = _ExpenseItem;

  factory ExpenseItem.fromJson(Map<String, dynamic> json) =>
      _$ExpenseItemFromJson(json);
}

/// 精算結果（誰が誰にいくら払うか）
@freezed
class SettlementItem with _$SettlementItem {
  const factory SettlementItem({
    required String fromUserId,
    required String toUserId,
    required int amount,
  }) = _SettlementItem;

  factory SettlementItem.fromJson(Map<String, dynamic> json) =>
      _$SettlementItemFromJson(json);
}

/// 予算計算ヘルパー
class ExpenseCalculator {
  /// 精算結果を計算
  static List<SettlementItem> calculateSettlements(
    List<ExpenseItem> expenses,
    List<String> allMembers,
  ) {
    if (expenses.isEmpty || allMembers.isEmpty) return [];

    // 各メンバーの収支を計算
    final balances = <String, int>{};
    for (final member in allMembers) {
      balances[member] = 0;
    }

    for (final expense in expenses) {
      final paidBy = expense.paidBy;
      final splitWith = expense.splitWith.isEmpty ? allMembers : expense.splitWith;
      final perPerson = expense.amount ~/ splitWith.length;

      // 支払った人はプラス
      balances[paidBy] = (balances[paidBy] ?? 0) + expense.amount;

      // 割り勘対象者はマイナス
      for (final member in splitWith) {
        balances[member] = (balances[member] ?? 0) - perPerson;
      }
    }

    // 精算を計算（シンプルなアルゴリズム）
    final settlements = <SettlementItem>[];
    final debtors = <String, int>{}; // 支払いが必要な人
    final creditors = <String, int>{}; // 受け取る人

    for (final entry in balances.entries) {
      if (entry.value < 0) {
        debtors[entry.key] = -entry.value;
      } else if (entry.value > 0) {
        creditors[entry.key] = entry.value;
      }
    }

    // マッチング
    for (final debtor in debtors.keys.toList()) {
      var debtAmount = debtors[debtor]!;
      for (final creditor in creditors.keys.toList()) {
        if (debtAmount <= 0) break;
        final creditAmount = creditors[creditor]!;
        if (creditAmount <= 0) continue;

        final settleAmount = debtAmount < creditAmount ? debtAmount : creditAmount;
        if (settleAmount > 0) {
          settlements.add(SettlementItem(
            fromUserId: debtor,
            toUserId: creditor,
            amount: settleAmount,
          ));
          debtAmount -= settleAmount;
          creditors[creditor] = creditAmount - settleAmount;
        }
      }
    }

    return settlements;
  }

  /// 総額を計算
  static int calculateTotal(List<ExpenseItem> expenses) {
    return expenses.fold(0, (sum, e) => sum + e.amount);
  }

  /// 1人あたりの金額を計算
  static int calculatePerPerson(List<ExpenseItem> expenses, int memberCount) {
    if (memberCount <= 0) return 0;
    return calculateTotal(expenses) ~/ memberCount;
  }
}
