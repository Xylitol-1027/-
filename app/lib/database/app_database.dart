import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// 折半/立替/空白フラグ。design.md 6.1節参照。
enum SplitType { none, split, advance }

/// 支払者。同棲する二人の固定の内部表現(表示名はAppSettingsで別管理)。
enum Payer { self, partner }

/// 支出が生活に必要か浪費かの判定。design.md 5章参照。
enum Necessity { necessary, wasteful }

/// カテゴリ。design.md 3.1節参照。
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get defaultNecessity => textEnum<Necessity>()();
  IntColumn get sortOrder => integer()();
  TextColumn get icon => text().withDefault(const Constant('tag'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 取引(支出)。design.md 3.2節参照。
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get payee => text()();
  IntColumn get categoryId =>
      integer().references(Categories, #id)();
  IntColumn get amount => integer()();
  TextColumn get splitType => textEnum<SplitType>()();
  TextColumn get payer => textEnum<Payer>()();
  TextColumn get necessity => textEnum<Necessity>()();
  IntColumn get settlementId =>
      integer().nullable().references(Settlements, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 精算履歴。design.md 3.3節参照。
class Settlements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get settledAt => dateTime()();
  IntColumn get netAmount => integer()();
  TextColumn get debtor => textEnum<Payer>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 表示名・色・既定フラグなどのアプリ設定(常に単一行)。design.md 3.5節参照。
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  IntColumn get id => integer()();
  TextColumn get selfName => text().withDefault(const Constant('自分'))();
  TextColumn get partnerName => text().withDefault(const Constant('相手'))();
  IntColumn get selfColorIndex => integer().withDefault(const Constant(0))();
  IntColumn get partnerColorIndex =>
      integer().withDefault(const Constant(1))();
  TextColumn get defaultSplitType =>
      textEnum<SplitType>().withDefault(const Constant('none'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// カテゴリ初期データ。design.md 3.1節「初期データ」に対応。
const List<(String, Necessity, String)> kInitialCategories = [
  ('食費', Necessity.necessary, 'food'),
  ('日用品', Necessity.necessary, 'daily'),
  ('住居費', Necessity.necessary, 'housing'),
  ('通信費', Necessity.necessary, 'comm'),
  ('交通費', Necessity.necessary, 'transport'),
  ('娯楽費', Necessity.wasteful, 'fun'),
  ('交際費', Necessity.wasteful, 'social'),
  ('美容', Necessity.wasteful, 'beauty'),
];

@DriftDatabase(tables: [Categories, Transactions, Settlements, AppSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
      );

  Future<void> _seed() async {
    for (var i = 0; i < kInitialCategories.length; i++) {
      final (name, necessity, icon) = kInitialCategories[i];
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: name,
          defaultNecessity: necessity,
          sortOrder: i,
          icon: Value(icon),
        ),
      );
    }
    await into(appSettingsTable).insert(
      const AppSettingsTableCompanion(id: Value(1)),
    );
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'kakeibo.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
