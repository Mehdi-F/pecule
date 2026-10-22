import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../format.dart';
import '../../models.dart';
import '../../store.dart';
import '../import_flow.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tx_sheet.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late DateTime _month;
  int _mode = 0; // 0 sorties, 1 entrées

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    if (store.txs.isNotEmpty && store.monthTxs(_month).isEmpty) {
      final latest = store.txs.first.date;
      _month = DateTime(latest.year, latest.month);
    }
  }

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final expenses = _mode == 0;
        final totals = store.totals(_month, expenses: expenses);
        final total = totals.fold<int>(0, (s, c) => s + c.cents);
        final income = store.monthTotal(_month, expenses: false);
        final spent = store.monthTotal(_month, expenses: true);
        return Scaffold(
          appBar: AppBar(title: const Text('Analyse')),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.arrow_back_rounded)),
                        Expanded(
                          child: Text(monthTitle(_month), textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        ),
                        IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.arrow_forward_rounded)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PillToggle(labels: const ['Sorties', 'Entrées'], index: _mode, onChanged: (i) => setState(() => _mode = i)),
                  ],
                ),
              ),
              AppCard(
                child: totals.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('Aucune opération ce mois-ci', textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted)),
                      )
                    : _Donut(totals: totals, total: total, expenses: expenses),
              ),
              if (expenses) _BudgetCard(spent: spent),
              _MonthSummary(income: income, spent: spent),
              if (totals.isNotEmpty)
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Column(
                    children: [
                      for (final c in totals)
                        _CategoryRow(
                          total: c,
                          share: total == 0 ? 0 : c.cents / total,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => CategoryTxScreen(month: _month, category: c.category, expenses: expenses),
                          )),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Donut extends StatelessWidget {
  final List<CategoryTotal> totals;
  final int total;
  final bool expenses;
  const _Donut({required this.totals, required this.total, required this.expenses});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: 84,
              pieTouchData: PieTouchData(enabled: false),
              sections: [
                for (final c in totals)
                  PieChartSectionData(
                    value: c.cents.toDouble(),
                    color: Color(c.category.color),
                    radius: 30,
                    showTitle: false,
                    badgeWidget: c.cents / total >= 0.07
                        ? Icon(iconFor(c.category.icon), size: 16, color: Colors.white)
                        : null,
                    badgePositionPercentageOffset: 0.5,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(money(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(expenses ? 'Sorties d\'argent' : 'Entrées d\'argent', style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final int spent;
  const _BudgetCard({required this.spent});

  @override
  Widget build(BuildContext context) {
    final budget = store.budgetCents;
    if (budget == null || budget <= 0) {
      return AppCard(
        onTap: () => editBudget(context),
        child: const Row(
          children: [
            Icon(Icons.pie_chart_rounded, color: AppColors.muted),
            SizedBox(width: 10),
            Expanded(child: Text('Définir un budget mensuel', style: TextStyle(fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      );
    }
    final ratio = spent / budget;
    final over = ratio > 1;
    return AppCard(
      onTap: () => editBudget(context),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: AppColors.muted),
              const SizedBox(width: 8),
              const Text('Budget', style: TextStyle(color: AppColors.muted, fontSize: 16)),
              const Spacer(),
              Text.rich(TextSpan(children: [
                TextSpan(text: money(spent), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                TextSpan(text: ' / ${money(budget)}', style: const TextStyle(color: AppColors.muted)),
              ]), style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: AppColors.line,
                    color: over ? AppColors.red : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(ratio * 100).round()} %',
                  style: TextStyle(fontWeight: FontWeight.w700, color: over ? AppColors.red : AppColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              over ? 'Dépassé de ${money(spent - budget)}' : 'Reste ${money(budget - spent)}',
              style: TextStyle(color: over ? AppColors.red : AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  final int income;
  final int spent;
  const _MonthSummary({required this.income, required this.spent});

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, Color color) => Expanded(
          child: Column(
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
              ),
            ],
          ),
        );
    final diff = income - spent;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: [
          cell('Entrées', money(income), AppColors.green),
          cell('Sorties', money(spent), AppColors.ink),
          cell('Bilan', signedMoney(diff), diff < 0 ? AppColors.red : AppColors.green),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryTotal total;
  final double share;
  final VoidCallback onTap;
  const _CategoryRow({required this.total, required this.share, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          children: [
            CategoryAvatar(total.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(total.category.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                  Text('${total.count} opération${total.count > 1 ? 's' : ''} · ${(share * 100).toStringAsFixed(share < 0.1 ? 1 : 0)} %',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            Text(money(total.cents), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class CategoryTxScreen extends StatelessWidget {
  final DateTime month;
  final Category category;
  final bool expenses;
  const CategoryTxScreen({super.key, required this.month, required this.category, required this.expenses});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store
            .monthTxs(month)
            .where((t) => t.isExpense == expenses && (t.categoryId ?? -1) == category.id && store.netCents(t) != 0)
            .toList();
        final total = list.fold<int>(0, (s, t) => s + store.netCents(t).abs());
        return Scaffold(
          appBar: AppBar(
            title: Text(category.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              AppCard(
                child: Row(
                  children: [
                    CategoryAvatar(category, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(monthTitle(month), style: const TextStyle(color: AppColors.muted)),
                          Text(money(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Plus aucune opération dans cette catégorie.', textAlign: TextAlign.center),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: Column(
                    children: [for (final t in list) TxTile(t, showDate: true, onTap: () => showTxSheet(context, t.id))],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
