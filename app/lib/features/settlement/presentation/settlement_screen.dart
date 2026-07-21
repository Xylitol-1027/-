import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../settings/data/app_settings_repository.dart';
import '../data/settlement_repository.dart';
import '../domain/settlement_calculator.dart';

/// 精算画面。design.md 7.2節・5章参照。
/// 「すべて/日付指定」を切り替え、対象の未精算取引と負債状況を表示し、精算を実行する。
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  SettlementScope _scope = SettlementScope.all;
  DateTime _cutoffDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsStreamProvider);
    final historyAsync = ref.watch(settlementHistoryStreamProvider);
    final settingsAsync = ref.watch(appSettingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('精算')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
        data: (allTransactions) {
          final settings = settingsAsync.value;
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final targets = scopedTransactions(
            allTransactions,
            scope: _scope,
            cutoffDate: _cutoffDate,
          )..sort((a, b) => b.date.compareTo(a.date));
          final outcome = computeSettlementOutcome(targets);
          final history = historyAsync.value ?? const [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<SettlementScope>(
                segments: const [
                  ButtonSegment(value: SettlementScope.all, label: Text('すべて')),
                  ButtonSegment(value: SettlementScope.date, label: Text('日付指定')),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
              if (_scope == SettlementScope.date) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    'この日付以前の分を対象: '
                    '${_cutoffDate.year}/${_cutoffDate.month}/${_cutoffDate.day}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _cutoffDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _cutoffDate = picked);
                  },
                ),
              ],
              const SizedBox(height: 16),
              _BalanceCard(
                outcome: outcome,
                selfName: settings.selfName,
                partnerName: settings.partnerName,
                onSettle: outcome == null
                    ? null
                    : () => _confirmAndSettle(
                        context,
                        allTransactions,
                        outcome,
                        settings,
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                '対象の取引（${targets.length}件）',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (targets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('折半・立替の取引を登録すると、ここに未精算分として表示されます。'),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final t in targets)
                        ListTile(
                          title: Text(t.payee),
                          subtitle: Text(
                            '${t.date.month}/${t.date.day} ・ '
                            '${t.splitType == SplitType.split ? "折半" : "立替"} ・ '
                            '${t.payer == Payer.self ? settings.selfName : settings.partnerName}払い ・ '
                            '¥${t.amount}',
                          ),
                          trailing: Builder(
                            builder: (context) {
                              final signed = signedAmount(t);
                              return Text(
                                '${signed >= 0 ? "+" : "-"}¥${signed.abs()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: signed >= 0 ? Colors.green : Colors.red,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text('精算履歴', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                child: history.isEmpty
                    ? const ListTile(title: Text('精算履歴はまだありません'))
                    : Column(
                        children: [
                          for (final s in history)
                            ListTile(
                              title: Text(
                                '${s.settledAt.year}-${s.settledAt.month.toString().padLeft(2, '0')}-'
                                '${s.settledAt.day.toString().padLeft(2, '0')} ・ '
                                '${s.debtor == Payer.self ? settings.selfName : settings.partnerName} → '
                                '${s.debtor == Payer.self ? settings.partnerName : settings.selfName}',
                              ),
                              trailing: Text(
                                '¥${s.netAmount}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndSettle(
    BuildContext context,
    List<Transaction> allTransactions,
    SettlementOutcome outcome,
    AppSettingsTableData settings,
  ) async {
    final debtorName = outcome.debtor == Payer.self
        ? settings.selfName
        : settings.partnerName;
    final creditorName = outcome.debtor == Payer.self
        ? settings.partnerName
        : settings.selfName;
    final scopeNote = _scope == SettlementScope.date
        ? '${_cutoffDate.year}/${_cutoffDate.month}/${_cutoffDate.day} 以前の分だけが対象です。'
            'それより後の取引は未精算のまま残ります。'
        : '対象の未精算取引すべてに精算済みの記録が付きます。';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¥${outcome.netAmount} を精算しますか？'),
        content: Text('$debtorNameから$creditorNameへ¥${outcome.netAmount}支払われた前提で、$scopeNote'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('精算する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(settlementRepositoryProvider)
        .settle(
          allTransactions: allTransactions,
          scope: _scope,
          cutoffDate: _cutoffDate,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('精算しました')));
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.outcome,
    required this.selfName,
    required this.partnerName,
    required this.onSettle,
  });

  final SettlementOutcome? outcome;
  final String selfName;
  final String partnerName;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owesToSelf = outcome != null && outcome!.debtor == Payer.partner;
    final background = outcome == null
        ? scheme.primaryContainer
        : (owesToSelf ? scheme.primaryContainer : scheme.errorContainer);
    final foreground = outcome == null
        ? scheme.onPrimaryContainer
        : (owesToSelf ? scheme.onPrimaryContainer : scheme.onErrorContainer);

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              outcome == null
                  ? '精算済みです'
                  : '${owesToSelf ? partnerName : selfName} → '
                        '${owesToSelf ? selfName : partnerName}（未精算分の合計）',
              style: TextStyle(color: foreground),
            ),
            const SizedBox(height: 6),
            Text(
              outcome == null ? '¥0' : '¥${outcome!.netAmount}',
              style: TextStyle(
                color: foreground,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (outcome != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onSettle,
                style: FilledButton.styleFrom(
                  backgroundColor: foreground,
                  foregroundColor: background,
                ),
                child: const Text('精算する'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
