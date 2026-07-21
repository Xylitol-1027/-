import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kakeibo/database/app_database.dart';
import 'package:kakeibo/features/settlement/domain/settlement_calculator.dart';

Transaction _tx({
  int id = 1,
  DateTime? date,
  String payee = 'テスト店',
  int categoryId = 1,
  required int amount,
  required SplitType splitType,
  required Payer payer,
  Necessity necessity = Necessity.necessary,
  int? settlementId,
}) {
  final now = DateTime(2026, 7, 21);
  return Transaction(
    id: id,
    date: date ?? now,
    payee: payee,
    categoryId: categoryId,
    amount: amount,
    splitType: splitType,
    payer: payer,
    necessity: necessity,
    settlementId: settlementId,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('signedAmount', () {
    test('折半は金額の1/2を、支払者が自分なら+、相手なら-で返す', () {
      final self = _tx(amount: 6000, splitType: SplitType.split, payer: Payer.self);
      final partner = _tx(amount: 6000, splitType: SplitType.split, payer: Payer.partner);
      expect(signedAmount(self), 3000);
      expect(signedAmount(partner), -3000);
    });

    test('立替は金額の全額(1/1)を、支払者が自分なら+、相手なら-で返す', () {
      final self = _tx(amount: 8400, splitType: SplitType.advance, payer: Payer.self);
      final partner = _tx(amount: 8400, splitType: SplitType.advance, payer: Payer.partner);
      expect(signedAmount(self), 8400);
      expect(signedAmount(partner), -8400);
    });

    test('空白は常に0を返す(負債計算に含めない)', () {
      final t = _tx(amount: 5000, splitType: SplitType.none, payer: Payer.self);
      expect(signedAmount(t), 0);
    });

    test('折半で割り切れない金額は四捨五入する', () {
      // 333 / 2 = 166.5 -> 四捨五入で167
      final t = _tx(amount: 333, splitType: SplitType.split, payer: Payer.self);
      expect(signedAmount(t), 167);
    });
  });

  group('unsettledTransactions / calculateBalance', () {
    test('settlement_idが付いた取引・空白の取引は集計対象から除外される', () {
      final list = [
        _tx(id: 1, amount: 62000, splitType: SplitType.split, payer: Payer.partner),
        _tx(id: 2, amount: 3278, splitType: SplitType.none, payer: Payer.self),
        _tx(id: 3, amount: 8400, splitType: SplitType.advance, payer: Payer.self, settlementId: 99),
      ];
      final unsettled = unsettledTransactions(list);
      expect(unsettled.map((t) => t.id), [1]);
    });

    test('要件定義書の例(住居費62000円折半・相手払い等)で合計が一致する', () {
      final list = [
        _tx(id: 1, date: DateTime(2026, 7, 1), amount: 62000, splitType: SplitType.split, payer: Payer.partner),
        _tx(id: 2, date: DateTime(2026, 7, 10), amount: 8400, splitType: SplitType.advance, payer: Payer.self),
        _tx(id: 3, date: DateTime(2026, 7, 15), amount: 8600, splitType: SplitType.split, payer: Payer.partner),
        _tx(id: 4, date: DateTime(2026, 7, 18), amount: 3240, splitType: SplitType.split, payer: Payer.self),
        _tx(id: 5, date: DateTime(2026, 7, 19), amount: 6050, splitType: SplitType.split, payer: Payer.partner),
      ];
      final balance = calculateBalance(unsettledTransactions(list));
      // -31000 + 8400 - 4300 + 1620 - 3025 = -28305 (自分が相手に28305円支払うべき)
      expect(balance, -28305);
      final outcome = computeSettlementOutcome(unsettledTransactions(list));
      expect(outcome!.netAmount, 28305);
      expect(outcome.debtor, Payer.self);
    });

    test('balanceが0のときcomputeSettlementOutcomeはnullを返す(精算不要)', () {
      final list = [
        _tx(id: 1, amount: 1000, splitType: SplitType.split, payer: Payer.self),
        _tx(id: 2, amount: 1000, splitType: SplitType.split, payer: Payer.partner),
      ];
      expect(computeSettlementOutcome(unsettledTransactions(list)), isNull);
    });
  });

  group('scopedTransactions (日付指定の部分精算)', () {
    test('日付指定で、指定日より後の取引は対象から除外される', () {
      final list = [
        _tx(id: 1, date: DateTime(2026, 7, 1), amount: 62000, splitType: SplitType.split, payer: Payer.partner),
        _tx(id: 2, date: DateTime(2026, 7, 10), amount: 8400, splitType: SplitType.advance, payer: Payer.self),
        _tx(id: 3, date: DateTime(2026, 7, 15), amount: 8600, splitType: SplitType.split, payer: Payer.partner),
        _tx(id: 4, date: DateTime(2026, 7, 18), amount: 3240, splitType: SplitType.split, payer: Payer.self),
        _tx(id: 5, date: DateTime(2026, 7, 19), amount: 6050, splitType: SplitType.split, payer: Payer.partner),
      ];
      final scoped = scopedTransactions(
        list,
        scope: SettlementScope.date,
        cutoffDate: DateTime(2026, 7, 15),
      );
      expect(scoped.map((t) => t.id).toSet(), {1, 2, 3});

      final remaining = list.where((t) => !scoped.map((s) => s.id).contains(t.id));
      expect(remaining.map((t) => t.id).toSet(), {4, 5});
    });

    test('精算実行後にsettlement_idを付与すると、次回はその取引が対象から外れる', () {
      var list = [
        _tx(id: 1, date: DateTime(2026, 7, 1), amount: 62000, splitType: SplitType.split, payer: Payer.partner),
        _tx(id: 2, date: DateTime(2026, 7, 18), amount: 3240, splitType: SplitType.split, payer: Payer.self),
      ];
      final firstScope = scopedTransactions(list, scope: SettlementScope.date, cutoffDate: DateTime(2026, 7, 1));
      expect(firstScope.map((t) => t.id), [1]);

      // 精算実行: id=1にsettlement_idを付与(実際はDriftのUPDATEに相当)
      list = list.map((t) => t.id == 1 ? t.copyWith(settlementId: const Value(100)) : t).toList();

      final afterSettle = unsettledTransactions(list);
      expect(afterSettle.map((t) => t.id), [2]);

      // 精算後に過去日付の取引を追加登録しても、settlement_idはNULLのままなので次回精算時に対象になる
      list = [
        ...list,
        _tx(id: 3, date: DateTime(2026, 6, 20), amount: 500, splitType: SplitType.split, payer: Payer.self),
      ];
      final afterBackdatedEntry = unsettledTransactions(list);
      expect(afterBackdatedEntry.map((t) => t.id).toSet(), {2, 3});
    });
  });
}
