import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../../shared/category_icons.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  /// 表示順(sort_order)に並んだカテゴリ一覧を監視する。design.md 3.1節参照。
  Stream<List<Category>> watchAll() {
    return (_db.select(_db.categories)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<Category?> findById(int id) {
    return (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> add(String name) async {
    final maxOrder = await (_db.selectOnly(_db.categories)
          ..addColumns([_db.categories.sortOrder.max()]))
        .map((row) => row.read(_db.categories.sortOrder.max()))
        .getSingleOrNull();
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            defaultNecessity: Necessity.necessary,
            sortOrder: (maxOrder ?? -1) + 1,
            icon: const Value(kDefaultCategoryIcon),
          ),
        );
  }

  Future<void> updateNecessity(int id, Necessity necessity) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(defaultNecessity: Value(necessity)),
    );
  }

  Future<void> updateIcon(int id, String icon) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(icon: Value(icon)),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }

  /// ドラッグ&ドロップによる並び替え結果をsort_orderへ反映する。design.md 7.2節参照。
  Future<void> reorder(List<Category> newOrder) async {
    await _db.transaction(() async {
      for (var i = 0; i < newOrder.length; i++) {
        await (_db.update(
          _db.categories,
        )..where((t) => t.id.equals(newOrder[i].id))).write(
          CategoriesCompanion(sortOrder: Value(i)),
        );
      }
    });
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(appDatabaseProvider));
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});
