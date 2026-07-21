import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../category/data/category_repository.dart';
import '../../transaction/data/transaction_repository.dart';

enum _PeriodMode { month, year }

/// サマリー画面。design.md 7.2節参照。
/// 月次/年次を切り替え、カテゴリ別支出割合をドーナツ円グラフ+凡例で表示する。
/// 「必要/浪費」の合計金額・比率も表示する。
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  _PeriodMode _mode = _PeriodMode.month;
  late DateTime _anchor = DateTime.now();

  static const _categoryPalette = [
    Color(0xFF2A78D6),
    Color(0xFFEB6834),
    Color(0xFF1BAF7A),
    Color(0xFFEDA100),
    Color(0xFFE87BA4),
    Color(0xFF008300),
    Color(0xFF4A3AA7),
    Color(0xFFE34948),
  ];

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('サマリー')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
        data: (transactions) {
          final categories = categoriesAsync.value ?? const [];
          if (categories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final categoryById = {for (final c in categories) c.id: c};

          final scoped = transactions.where((t) {
            if (_mode == _PeriodMode.month) {
              return t.date.year == _anchor.year && t.date.month == _anchor.month;
            }
            return t.date.year == _anchor.year;
          }).toList();

          final totalsByCategory = <int, int>{};
          var goodTotal = 0;
          var wastefulTotal = 0;
          for (final t in scoped) {
            totalsByCategory.update(
              t.categoryId,
              (v) => v + t.amount,
              ifAbsent: () => t.amount,
            );
            if (t.necessity == Necessity.necessary) {
              goodTotal += t.amount;
            } else {
              wastefulTotal += t.amount;
            }
          }
          final grandTotal = goodTotal + wastefulTotal;
          final rows =
              totalsByCategory.entries.map((e) {
                  return (
                    category: categoryById[e.key],
                    amount: e.value,
                  );
                }).toList()
                ..sort((a, b) => b.amount.compareTo(a.amount));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<_PeriodMode>(
                segments: const [
                  ButtonSegment(value: _PeriodMode.month, label: Text('月次')),
                  ButtonSegment(value: _PeriodMode.year, label: Text('年次')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _anchor = _mode == _PeriodMode.month
                        ? DateTime(_anchor.year, _anchor.month - 1)
                        : DateTime(_anchor.year - 1, _anchor.month)),
                  ),
                  Text(
                    _mode == _PeriodMode.month
                        ? '${_anchor.year}年${_anchor.month}月'
                        : '${_anchor.year}年',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _anchor = _mode == _PeriodMode.month
                        ? DateTime(_anchor.year, _anchor.month + 1)
                        : DateTime(_anchor.year + 1, _anchor.month)),
                  ),
                ],
              ),
              if (scoped.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('この期間の取引はありません')),
                )
              else ...[
                SizedBox(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 1,
                          centerSpaceRadius: 60,
                          sections: [
                            for (var i = 0; i < rows.length; i++)
                              PieChartSectionData(
                                value: rows[i].amount.toDouble(),
                                color: _categoryPalette[i % _categoryPalette.length],
                                title: '',
                                radius: 46,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _mode == _PeriodMode.month ? '月間支出合計' : '年間支出合計',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            '¥$grandTotal',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('カテゴリ別内訳', style: Theme.of(context).textTheme.labelLarge),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 6,
                            backgroundColor:
                                _categoryPalette[i % _categoryPalette.length],
                          ),
                          title: Text(rows[i].category?.name ?? ''),
                          trailing: Text(
                            '¥${rows[i].amount} '
                            '(${grandTotal == 0 ? 0 : (rows[i].amount * 100 / grandTotal).round()}%)',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('必要 / 浪費', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        Expanded(
                          flex: goodTotal == 0 ? 1 : goodTotal,
                          child: Container(color: Colors.green),
                        ),
                        if (wastefulTotal > 0)
                          Expanded(
                            flex: wastefulTotal,
                            child: Container(color: Colors.orange),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: Colors.green, label: '必要 ¥$goodTotal'),
                    const SizedBox(width: 16),
                    _LegendDot(color: Colors.orange, label: '浪費 ¥$wastefulTotal'),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
