import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/category/presentation/category_management_screen.dart';
import '../features/receipt_scan/presentation/receipt_scan_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settlement/presentation/settlement_screen.dart';
import '../features/summary/presentation/summary_screen.dart';
import '../features/transaction/presentation/transaction_form_screen.dart';
import '../features/transaction/presentation/transaction_list_screen.dart';
import '../shared/widgets/app_shell.dart';

/// design.md 7.1節のルート構成(4タブ+FAB+各画面)。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/transactions',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionListScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const TransactionFormScreen(),
                ),
                GoRoute(
                  path: 'scan',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const ReceiptScanScreen(),
                ),
                GoRoute(
                  path: ':id/edit',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => TransactionFormScreen(
                    transactionId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settlement',
              builder: (context, state) => const SettlementScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/summary',
              builder: (context, state) => const SummaryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'categories',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      const CategoryManagementScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
