import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._db);

  final AppDatabase _db;

  static const _rowId = 1;

  /// 表示名・色・既定フラグなどのアプリ設定(常に単一行)。design.md 3.5節参照。
  Stream<AppSettingsTableData> watch() {
    return (_db.select(
      _db.appSettingsTable,
    )..where((t) => t.id.equals(_rowId))).watchSingle();
  }

  Future<void> updateNames({String? selfName, String? partnerName}) {
    return (_db.update(
      _db.appSettingsTable,
    )..where((t) => t.id.equals(_rowId))).write(
      AppSettingsTableCompanion(
        selfName: selfName != null ? Value(selfName) : const Value.absent(),
        partnerName: partnerName != null
            ? Value(partnerName)
            : const Value.absent(),
      ),
    );
  }

  /// 自分/相手の色は同じ色を選べない。既に使われている色を選んだ場合は
  /// もう一方と入れ替える。design.md 3.5節参照。
  Future<void> setPersonColor({required bool isSelf, required int index}) async {
    final current = await (_db.select(
      _db.appSettingsTable,
    )..where((t) => t.id.equals(_rowId))).getSingle();

    var selfIndex = current.selfColorIndex;
    var partnerIndex = current.partnerColorIndex;
    if (isSelf) {
      if (partnerIndex == index) partnerIndex = selfIndex;
      selfIndex = index;
    } else {
      if (selfIndex == index) selfIndex = partnerIndex;
      partnerIndex = index;
    }

    await (_db.update(_db.appSettingsTable)..where((t) => t.id.equals(_rowId)))
        .write(
          AppSettingsTableCompanion(
            selfColorIndex: Value(selfIndex),
            partnerColorIndex: Value(partnerIndex),
          ),
        );
  }

  Future<void> updateDefaultSplitType(SplitType splitType) {
    return (_db.update(
      _db.appSettingsTable,
    )..where((t) => t.id.equals(_rowId))).write(
      AppSettingsTableCompanion(defaultSplitType: Value(splitType)),
    );
  }
}

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(appDatabaseProvider));
});

final appSettingsStreamProvider = StreamProvider<AppSettingsTableData>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watch();
});
