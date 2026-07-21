import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../category/data/category_repository.dart';
import '../../settings/data/app_settings_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_draft.dart';

/// 取引追加・編集画面。design.md 7.2節参照。
/// 支払先が過去の取引と一致する場合、直近1回に使ったカテゴリを自動反映する
/// (ユーザーがまだ手動でカテゴリを選んでいない場合のみ)。
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transactionId, this.prefill});

  /// 指定があれば編集モード。
  final int? transactionId;

  /// レシートOCRからの事前入力(スキャン確認画面から遷移した場合)。
  final TransactionDraft? prefill;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _payeeController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _date = DateTime.now();
  int? _categoryId;
  SplitType _splitType = SplitType.none;
  Payer _payer = Payer.self;
  Necessity _necessity = Necessity.necessary;
  bool _categoryTouched = false;
  bool _loaded = false;

  bool get _isEditing => widget.transactionId != null;

  @override
  void dispose() {
    _payeeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (_loaded) return;
    _loaded = true;

    if (widget.prefill != null) {
      final t = widget.prefill!;
      _date = t.date;
      _payeeController.text = t.payee;
      _amountController.text = t.amount.toString();
      _categoryId = t.categoryId;
      _splitType = t.splitType;
      _payer = t.payer;
      _necessity = t.necessity;
      setState(() {});
      return;
    }

    if (_isEditing) {
      final t = await ref
          .read(transactionRepositoryProvider)
          .findById(widget.transactionId!);
      if (t != null) {
        _date = t.date;
        _payeeController.text = t.payee;
        _amountController.text = t.amount.toString();
        _categoryId = t.categoryId;
        _splitType = t.splitType;
        _payer = t.payer;
        _necessity = t.necessity;
        _categoryTouched = true;
      }
      setState(() {});
    } else {
      final settings = await ref.read(appSettingsStreamProvider.future);
      _splitType = settings.defaultSplitType;
      setState(() {});
    }
  }

  Future<void> _onPayeeSubmitted(String value) async {
    if (_categoryTouched) return;
    final categoryId = await ref
        .read(transactionRepositoryProvider)
        .lastCategoryIdForPayee(value);
    if (categoryId == null || categoryId == _categoryId) return;
    final categories = ref.read(categoriesStreamProvider).value ?? [];
    Category? category;
    for (final c in categories) {
      if (c.id == categoryId) {
        category = c;
        break;
      }
    }
    final resolvedCategory = category;
    if (resolvedCategory == null) return;
    setState(() {
      _categoryId = categoryId;
      _necessity = resolvedCategory.defaultNecessity;
    });
  }

  @override
  Widget build(BuildContext context) {
    _loadInitial();
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final payeeHistoryAsync = ref.watch(payeeHistoryStreamProvider);
    final settingsAsync = ref.watch(appSettingsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.prefill != null
              ? '読み取り内容の確認'
              : (_isEditing ? '取引を編集' : '取引を追加'),
        ),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
        data: (categories) {
          if (categories.isEmpty) return const SizedBox.shrink();
          _categoryId ??= categories.first.id;
          final settings = settingsAsync.value;
          final payeeOptions = payeeHistoryAsync.value ?? const [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.prefill != null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('レシートを読み取りました。内容を確認し、必要なら修正してから登録してください。'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              InputDatePickerFormField(
                fieldLabelText: '日付',
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                onDateSubmitted: (d) => setState(() => _date = d),
                onDateSaved: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _payeeController.text),
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return const Iterable.empty();
                  return payeeOptions.where(
                    (p) => p.toLowerCase().contains(value.text.toLowerCase()),
                  );
                },
                onSelected: (value) {
                  _payeeController.text = value;
                  _onPayeeSubmitted(value);
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  controller.text = _payeeController.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: '支払先',
                      hintText: '例）西友 経堂店',
                      helperText: '入力すると過去の支払先候補が表示されます',
                    ),
                    onChanged: (v) => _payeeController.text = v,
                    onSubmitted: (v) => _onPayeeSubmitted(v),
                    onTapOutside: (_) {
                      focusNode.unfocus();
                      _onPayeeSubmitted(controller.text);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('カテゴリ', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() {
                        _categoryId = c.id;
                        _necessity = c.defaultNecessity;
                        _categoryTouched = true;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '金額', prefixText: '¥ '),
              ),
              const SizedBox(height: 16),
              Text('折半 / 立替 / 空白', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<SplitType>(
                segments: const [
                  ButtonSegment(value: SplitType.none, label: Text('空白')),
                  ButtonSegment(value: SplitType.split, label: Text('折半')),
                  ButtonSegment(value: SplitType.advance, label: Text('立替')),
                ],
                selected: {_splitType},
                onSelectionChanged: (s) => setState(() => _splitType = s.first),
              ),
              const SizedBox(height: 16),
              Text('支払者', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<Payer>(
                segments: [
                  ButtonSegment(
                    value: Payer.self,
                    label: Text(settings?.selfName ?? '自分'),
                  ),
                  ButtonSegment(
                    value: Payer.partner,
                    label: Text(settings?.partnerName ?? '相手'),
                  ),
                ],
                selected: {_payer},
                onSelectionChanged: (s) => setState(() => _payer = s.first),
              ),
              const SizedBox(height: 16),
              Text('必要 / 浪費', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<Necessity>(
                segments: const [
                  ButtonSegment(value: Necessity.necessary, label: Text('必要')),
                  ButtonSegment(value: Necessity.wasteful, label: Text('浪費')),
                ],
                selected: {_necessity},
                onSelectionChanged: (s) => setState(() => _necessity = s.first),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? '保存する' : '登録する'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('この取引を削除'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    final payee = _payeeController.text.trim().isEmpty
        ? '（未入力）'
        : _payeeController.text.trim();
    final repo = ref.read(transactionRepositoryProvider);
    final now = DateTime.now();

    if (_isEditing) {
      await repo.update(
        widget.transactionId!,
        TransactionsCompanion(
          date: Value(_date),
          payee: Value(payee),
          categoryId: Value(_categoryId!),
          amount: Value(amount),
          splitType: Value(_splitType),
          payer: Value(_payer),
          necessity: Value(_necessity),
          updatedAt: Value(now),
        ),
      );
    } else {
      await repo.add(
        TransactionsCompanion.insert(
          date: _date,
          payee: payee,
          categoryId: _categoryId!,
          amount: amount,
          splitType: _splitType,
          payer: _payer,
          necessity: _necessity,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この取引を削除しますか？'),
        content: const Text('削除すると元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(transactionRepositoryProvider)
          .delete(widget.transactionId!);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
