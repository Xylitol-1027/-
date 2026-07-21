import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../database/app_database.dart';
import '../../../shared/theme/person_colors.dart';
import '../data/app_settings_repository.dart';

/// 設定画面。design.md 7.2節参照。
/// 表示名・色、既定の折半/立替/空白フラグ、カテゴリ管理への導線、バックアップ説明を表示する。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
        data: (settings) {
          final repo = ref.read(appSettingsRepositoryProvider);
          final brightness = Theme.of(context).brightness;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionTitle('呼び方'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _NameField(
                        label: 'あなたの表示名',
                        initialValue: settings.selfName,
                        onChanged: (v) => repo.updateNames(selfName: v),
                      ),
                      const SizedBox(height: 12),
                      _NameField(
                        label: '同棲相手の表示名',
                        initialValue: settings.partnerName,
                        onChanged: (v) => repo.updateNames(partnerName: v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('あなたの色'),
                      const SizedBox(height: 8),
                      _ColorRow(
                        selectedIndex: settings.selfColorIndex,
                        brightness: brightness,
                        onSelect: (i) =>
                            repo.setPersonColor(isSelf: true, index: i),
                      ),
                      const SizedBox(height: 16),
                      const Text('同棲相手の色'),
                      const SizedBox(height: 8),
                      _ColorRow(
                        selectedIndex: settings.partnerColorIndex,
                        brightness: brightness,
                        onSelect: (i) =>
                            repo.setPersonColor(isSelf: false, index: i),
                      ),
                    ],
                  ),
                ),
              ),
              const _SectionTitle('既定のフラグ'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('新規登録時に最初から選ばれている状態'),
                      const SizedBox(height: 8),
                      SegmentedButton<SplitType>(
                        segments: const [
                          ButtonSegment(value: SplitType.none, label: Text('空白')),
                          ButtonSegment(value: SplitType.split, label: Text('折半')),
                          ButtonSegment(
                            value: SplitType.advance,
                            label: Text('立替'),
                          ),
                        ],
                        selected: {settings.defaultSplitType},
                        onSelectionChanged: (selection) =>
                            repo.updateDefaultSplitType(selection.first),
                      ),
                    ],
                  ),
                ),
              ),
              const _SectionTitle('家計簿'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('カテゴリ管理'),
                  subtitle: const Text('カテゴリの追加・編集・必要/浪費のデフォルト設定'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/categories'),
                ),
              ),
              const _SectionTitle('データ'),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.backup_outlined),
                  title: Text('バックアップ'),
                  subtitle: Text('Android標準の自動バックアップが有効です。ログインは不要です。'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(labelText: widget.label),
      onSubmitted: widget.onChanged,
      onTapOutside: (_) => widget.onChanged(_controller.text),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.selectedIndex,
    required this.brightness,
    required this.onSelect,
  });

  final int selectedIndex;
  final Brightness brightness;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: [
        for (var i = 0; i < kPersonColorSwatches.length; i++)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onSelect(i),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: personColorFor(i, brightness),
                border: i == selectedIndex
                    ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 2,
                      )
                    : null,
              ),
              child: i == selectedIndex
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}
