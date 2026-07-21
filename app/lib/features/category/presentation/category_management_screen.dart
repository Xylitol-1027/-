import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../shared/category_icons.dart';
import '../data/category_repository.dart';

/// カテゴリ管理画面。design.md 7.2節参照。
/// アイコン選択、必要/浪費デフォルト、ドラッグ&ドロップでの並び替え、追加・削除に対応する。
class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリ管理')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
        data: (categories) {
          return Column(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: categories.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = [...categories];
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);
                    ref.read(categoryRepositoryProvider).reorder(reordered);
                  },
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    return ListTile(
                      key: ValueKey(c.id),
                      leading: IconButton(
                        icon: Icon(iconForId(c.icon)),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        onPressed: () => _openIconPicker(context, ref, c),
                      ),
                      title: Text(c.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SegmentedButton<Necessity>(
                            segments: const [
                              ButtonSegment(
                                value: Necessity.necessary,
                                label: Text('必要'),
                              ),
                              ButtonSegment(
                                value: Necessity.wasteful,
                                label: Text('浪費'),
                              ),
                            ],
                            selected: {c.defaultNecessity},
                            onSelectionChanged: (selection) {
                              ref
                                  .read(categoryRepositoryProvider)
                                  .updateNecessity(c.id, selection.first);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref
                                .read(categoryRepositoryProvider)
                                .delete(c.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      ref.read(categoryRepositoryProvider).add('新しいカテゴリ'),
                  icon: const Icon(Icons.add),
                  label: const Text('カテゴリを追加'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openIconPicker(BuildContext context, WidgetRef ref, Category category) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'アイコンを選択',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        for (final option in kCategoryIconOptions)
                          _IconChoice(
                            option: option,
                            selected: option.id == category.icon,
                            onTap: () {
                              ref
                                  .read(categoryRepositoryProvider)
                                  .updateIcon(category.id, option.id);
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CategoryIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: option.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected ? scheme.primaryContainer : scheme.surface,
          ),
          child: Icon(
            option.icon,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
