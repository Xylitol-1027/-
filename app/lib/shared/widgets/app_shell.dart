import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// ボトムナビゲーション4タブ + 支出一覧タブ限定のFAB。design.md 7.1節参照。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isTransactionsTab = navigationShell.currentIndex == 0;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: isTransactionsTab
          ? FloatingActionButton(
              onPressed: () => _showAddSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '支出一覧',
          ),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows_outlined),
            selectedIcon: Icon(Icons.compare_arrows),
            label: '精算',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_small_outlined),
            selectedIcon: Icon(Icons.donut_small),
            label: 'サマリー',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('レシートで登録'),
              subtitle: const Text('カメラで撮影して自動入力'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/transactions/scan');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('手入力で登録'),
              subtitle: const Text('フォームに直接入力'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/transactions/new');
              },
            ),
          ],
        ),
      ),
    );
  }
}
