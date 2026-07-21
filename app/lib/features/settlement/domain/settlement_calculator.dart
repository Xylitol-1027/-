import '../../../database/app_database.dart';

/// 精算画面の対象範囲。design.md 5.2節参照。
enum SettlementScope { all, date }

/// 未精算(settlement_id が null)かつ split_type が空白でない取引を返す。
List<Transaction> unsettledTransactions(List<Transaction> all) {
  return all
      .where((t) => t.settlementId == null && t.splitType != SplitType.none)
      .toList();
}

/// 精算画面の「すべて/日付指定」に応じて対象取引を絞り込む。design.md 5.2節参照。
List<Transaction> scopedTransactions(
  List<Transaction> all, {
  required SettlementScope scope,
  DateTime? cutoffDate,
}) {
  final unsettled = unsettledTransactions(all);
  if (scope == SettlementScope.all) return unsettled;
  assert(cutoffDate != null, 'date scope には cutoffDate が必須');
  return unsettled.where((t) => !t.date.isAfter(cutoffDate!)).toList();
}

/// 1件の取引が自分(self)視点の収支に与える符号付き金額。design.md 5.1節の式。
/// 折半は1/2、立替は1/1、端数は四捨五入。空白は常に0(負債計算に含めない)。
int signedAmount(Transaction t) {
  if (t.splitType == SplitType.none) return 0;
  final base = t.splitType == SplitType.split
      ? (t.amount / 2).round()
      : t.amount;
  return t.payer == Payer.self ? base : -base;
}

/// 対象取引群の自分(self)視点の収支合計。
/// balance > 0: 相手が自分に支払うべき。balance < 0: 自分が相手に支払うべき。
int calculateBalance(Iterable<Transaction> targets) {
  return targets.fold(0, (sum, t) => sum + signedAmount(t));
}

/// 精算実行結果。balanceが0ならnullを返す(精算不要)。
class SettlementOutcome {
  const SettlementOutcome({required this.netAmount, required this.debtor});

  final int netAmount;

  /// 負債があった側。
  final Payer debtor;
}

SettlementOutcome? computeSettlementOutcome(List<Transaction> targets) {
  final balance = calculateBalance(targets);
  if (balance == 0) return null;
  return SettlementOutcome(
    netAmount: balance.abs(),
    debtor: balance > 0 ? Payer.partner : Payer.self,
  );
}
