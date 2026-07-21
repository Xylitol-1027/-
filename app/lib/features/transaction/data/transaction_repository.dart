import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  /// 支払日の新しい順で取引一覧を監視する。design.md 7.2節「支出一覧」参照。
  Stream<List<Transaction>> watchAll() {
    return (_db.select(_db.transactions)..orderBy([
          (t) => OrderingTerm.desc(t.date),
          (t) => OrderingTerm.desc(t.id),
        ]))
        .watch();
  }

  Future<Transaction?> findById(int id) {
    return (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 過去に入力した支払先の一覧(オートコンプリート候補)。design.md 4章参照。
  Stream<List<String>> watchPayeeHistory() {
    final query = _db.selectOnly(_db.transactions, distinct: true)
      ..addColumns([_db.transactions.payee])
      ..orderBy([OrderingTerm.desc(_db.transactions.payee)]);
    return query.map((row) => row.read(_db.transactions.payee)!).watch();
  }

  /// 指定した支払先で直近1回に使ったカテゴリIDを返す(なければnull)。
  /// design.md 7.2節「取引追加・編集」参照。手動でカテゴリ選択済みの場合は
  /// 呼び出し側(UI)で上書きしないよう制御する。
  Future<int?> lastCategoryIdForPayee(String payee) async {
    final trimmed = payee.trim();
    if (trimmed.isEmpty) return null;
    final row =
        await (_db.select(_db.transactions)
              ..where((t) => t.payee.equals(trimmed))
              ..orderBy([
                (t) => OrderingTerm.desc(t.date),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.categoryId;
  }

  Future<int> add(TransactionsCompanion entry) {
    return _db.into(_db.transactions).insert(entry);
  }

  Future<void> update(int id, TransactionsCompanion entry) {
    return (_db.update(
      _db.transactions,
    )..where((t) => t.id.equals(id))).write(entry);
  }

  /// 確認ダイアログ表示後の物理削除。design.md 8章参照(ソフトデリートは行わない)。
  Future<void> delete(int id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(appDatabaseProvider));
});

final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAll();
});

final payeeHistoryStreamProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchPayeeHistory();
});
