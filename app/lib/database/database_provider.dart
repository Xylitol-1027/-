import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// アプリ全体で共有する単一のDrift DBインスタンス。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
