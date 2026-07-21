import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../database/app_database.dart';
import '../../../shared/category_icons.dart';
import '../../../shared/theme/person_colors.dart';
import '../../category/data/category_repository.dart';
import '../../settings/data/app_settings_repository.dart';
import '../data/transaction_repository.dart';

/// 支出一覧画面。design.md 7.2節参照。
/// 支払日の新しい順、カテゴリの線画アイコン、支払者名タグ(色付き)、必要/浪費タグを表示する。
class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final settingsAsync = ref.watch(appSettingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('支出一覧')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
        data: (transactions) {
          final categories = categoriesAsync.value ?? const [];
          final settings = settingsAsync.value;
          if (categories.isEmpty || settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (transactions.isEmpty) {
            return const _EmptyState();
          }
          final categoryById = {for (final c in categories) c.id: c};
          final brightness = Theme.of(context).brightness;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: transactions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = transactions[index];
              final category = categoryById[t.categoryId];
              final isGood = t.necessity == Necessity.necessary;
              final payerName = t.payer == Payer.self
                  ? settings.selfName
                  : settings.partnerName;
              final payerColorIndex = t.payer == Payer.self
                  ? settings.selfColorIndex
                  : settings.partnerColorIndex;

              return ListTile(
                onTap: () => context.push('/transactions/${t.id}/edit'),
                leading: CircleAvatar(
                  backgroundColor: isGood
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.18),
                  foregroundColor: isGood
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                  child: Icon(iconForId(category?.icon ?? kDefaultCategoryIcon)),
                ),
                title: Text(t.payee),
                subtitle: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${t.date.month}/${t.date.day} ・ ${category?.name ?? ''}'),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: CircleAvatar(
                        backgroundColor: personColorFor(payerColorIndex, brightness),
                        radius: 5,
                      ),
                      label: Text('$payerName払い'),
                      labelStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(isGood ? '必要' : '浪費'),
                      labelStyle: Theme.of(context).textTheme.labelSmall,
                      backgroundColor: isGood
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.18),
                    ),
                  ],
                ),
                trailing: Text(
                  '¥${t.amount}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('まだ取引がありません', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              '右下の + から、レシート撮影か手入力で最初の取引を登録しましょう。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
