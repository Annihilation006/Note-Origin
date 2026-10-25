import 'package:flutter/material.dart';

import 'budget_page.dart';
import 'home_page.dart';
import 'stats_page.dart';

/// 账本，把明细/统计/预算收进来。功能没动，只是归拢
class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        // 不叠AppBar，子页自带月份工具栏，这里只放一条tab
        body: Column(
          children: [
            Material(
              color: cs.surface,
              child: SafeArea(
                bottom: false,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tabs: const [
                    Tab(text: '明细'),
                    Tab(text: '统计'),
                    Tab(text: '预算'),
                  ],
                ),
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  HomePage(),
                  StatsPage(),
                  BudgetPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
