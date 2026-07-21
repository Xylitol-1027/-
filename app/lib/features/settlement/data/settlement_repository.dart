import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../domain/settlement_calculator.dart';

class SettlementRepository {
  SettlementRepository(this._db);

  final AppDatabase _db;

  Stream<List<Transaction>> watchAllTransactions() {
    return _db.select(_db.transactions).watch();
  }

  Stream<List<Settlement>> watchHistory() {
    return (_db.select(_db.settlements)..orderBy([
          (t) => OrderingTerm.desc(t.settledAt),
          (t) => OrderingTerm.desc(t.id),
        ]))
        .watch();
  }

  /// 「精算する」実行。design.md 5.2節参照。
  /// scopeで絞り込んだ対象取引にsettlement_idを一括で設定し、精算履歴を1件作成する。
  /// balanceが0(精算不要)の場合は何もせずnullを返す。
  Future<SettlementOutcome?> settle({
    required List<Transaction> allTransactions,
    required SettlementScope scope,
    DateTime? cutoffDate,
  }) async {
    final targets = scopedTransactions(
      allTransactions,
      scope: scope,
      cutoffDate: cutoffDate,
    );
    final outcome = computeSettlementOutcome(targets);
    if (outcome == null) return null;

    await _db.transaction(() async {
      final settlementId = await _db
          .into(_db.settlements)
          .insert(
            SettlementsCompanion.insert(
              settledAt: DateTime.now(),
              netAmount: outcome.netAmount,
              debtor: outcome.debtor,
            ),
          );
      for (final t in targets) {
        await (_db.update(
          _db.transactions,
        )..where((row) => row.id.equals(t.id))).write(
          TransactionsCompanion(settlementId: Value(settlementId)),
        );
      }
    });

    return outcome;
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepository(ref.watch(appDatabaseProvider));
});

final allTransactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(settlementRepositoryProvider).watchAllTransactions();
});

final settlementHistoryStreamProvider = StreamProvider<List<Settlement>>((ref) {
  return ref.watch(settlementRepositoryProvider).watchHistory();
});
