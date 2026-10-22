import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../categorizer.dart';
import '../../format.dart';
import '../../models.dart';
import '../../store.dart';
import '../import_flow.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tx_sheet.dart';

/// Nuances de vert pour les entrées (une couleur par sous-catégorie).
const List<int> _incomeShades = [
  0xFF34C759, 0xFF1E9E63, 0xFF7ED957, 0xFF0F7A4A, 0xFFA8E6A1, 0xFF4FB286, 0xFF2BB673, 0xFFB7EFC5,
];

DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late DateTime _month;
  int _mode = 0; // 0 sorties, 1 entrées
  int _view = 0; // 0 catégories, 1 simplifié

  @override
  void initState() {
    super.initState();
    _month = _monthOf(DateTime.now());
    if (store.txs.isNotEmpty && store.monthTxs(_month).isEmpty) {
      _month = store.analysisMonthOf(store.txs.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final expenses = _mode == 0;
        final income = store.monthTotal(_month, expenses: false);
        final spent = store.monthTotal(_month, expenses: true);
        final total = expenses ? spent : income;

        final List<_Slice> slices;
        final List<Widget> rows;
        if (expenses && _view == 1) {
          final groups = store.groupTotals(_month);
          slices = [
            for (final g in groupLabels.keys)
              if (groups[g]!.$1 > 0) _Slice(groups[g]!.$1, Color(groupColors[g]!), groupIcons[g]!),
          ];
          rows = [
            for (final g in groupLabels.keys)
              _AmountRow(
                icon: groupIcons[g]!,
                color: Color(groupColors[g]!),
                title: groupLabels[g]!,
                cents: groups[g]!.$1,
                count: groups[g]!.$2,
                total: total,
                onTap: () => _open(TxListScreen(
                  title: groupLabels[g]!,
                  month: _month,
                  expenses: true,
                  where: (t) => store.groupOf(store.categoryOf(t)) == g,
                )),
              ),
          ];
        } else if (expenses) {
          final tops = store.totals(_month, expenses: true);
          slices = [for (final c in tops) _Slice(c.cents, Color(c.category.color), c.category.icon)];
          rows = [
            for (final c in tops)
              _AmountRow(
                icon: c.category.icon,
                color: Color(c.category.color),
                title: c.category.name,
                cents: c.cents,
                count: c.count,
                total: total,
                onTap: () => _open(ParentCategoryScreen(parent: c.category, month: _month, expenses: true)),
              ),
          ];
        } else {
          final leaves = store.leafTotals(_month, expenses: false);
          final shown = {for (final c in leaves) c.category.id};
          final incomeParent = store.topCategories().where((c) => c.name == incomeParentName).firstOrNull;
          final zeros = incomeParent == null
              ? const <Category>[]
              : store.childrenOf(incomeParent.id).where((c) => !shown.contains(c.id)).toList();
          slices = [
            for (var i = 0; i < leaves.length; i++)
              _Slice(leaves[i].cents, Color(_incomeShades[i % _incomeShades.length]), leaves[i].category.icon),
          ];
          rows = [
            for (var i = 0; i < leaves.length; i++)
              _AmountRow(
                icon: leaves[i].category.icon,
                color: Color(_incomeShades[i % _incomeShades.length]),
                title: leaves[i].category.name,
                cents: leaves[i].cents,
                count: leaves[i].count,
                total: total,
                onTap: () => _openLeaf(leaves[i].category, false),
              ),
            for (final c in zeros)
              _AmountRow(
                icon: c.icon,
                color: const Color(0xFF34C759),
                title: c.name,
                cents: 0,
                count: 0,
                total: total,
                onTap: () => _openLeaf(c, false),
              ),
          ];
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Analyse')),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  children: [
                    MonthBar(month: _month, onChanged: (m) => setState(() => _month = m)),
                    const SizedBox(height: 8),
                    PillToggle(labels: const ['Sorties', 'Entrées'], index: _mode, onChanged: (i) => setState(() => _mode = i)),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  children: [
                    if (slices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('Aucune opération ce mois-ci', textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted)),
                      )
                    else
                      _Donut(slices: slices, total: total, expenses: expenses),
                    if (expenses) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 260,
                        child: PillToggle(
                          labels: const ['Catégories', 'Simplifié'],
                          index: _view,
                          onChanged: (i) => setState(() => _view = i),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (expenses) _BudgetCard(spent: spent),
              _MonthSummary(income: income, spent: spent),
              if (rows.isNotEmpty)
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  child: Column(children: _divided(rows)),
                ),
            ],
          ),
        );
      },
    );
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openLeaf(Category c, bool expenses) => _open(TxListScreen(
        title: c.name,
        month: _month,
        expenses: expenses,
        where: (t) => t.categoryId == c.id,
      ));
}

List<Widget> _divided(List<Widget> rows) => [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const Divider(height: 1, indent: 64, color: AppColors.line),
        rows[i],
      ],
    ];

/// Barre de mois ← Octobre 2026 →
class MonthBar extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const MonthBar({super.key, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(monthTitle(month), textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink)),
        ),
        IconButton(
          onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ],
    );
  }
}

class _Slice {
  final int cents;
  final Color color;
  final String icon;
  const _Slice(this.cents, this.color, this.icon);
}

class _Donut extends StatelessWidget {
  final List<_Slice> slices;
  final int total;
  final bool expenses;
  const _Donut({required this.slices, required this.total, required this.expenses});

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
                for (final s in slices)
                  PieChartSectionData(
                    value: s.cents.toDouble(),
                    color: s.color,
                    radius: 30,
                    showTitle: false,
                    badgeWidget: total > 0 && s.cents / total >= 0.07
                        ? Icon(iconFor(s.icon), size: 16, color: Colors.white)
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

/// Ligne « icône · nom · % • N transactions · montant › », grisée à 0 €.
class _AmountRow extends StatelessWidget {
  final String icon;
  final Color color;
  final String title;
  final int cents;
  final int count;
  final int total;
  final VoidCallback onTap;
  const _AmountRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.cents,
    required this.count,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final empty = cents == 0;
    final share = total == 0 ? 0.0 : cents / total;
    final pct = share == 0 ? '0' : (share < 0.01 ? '<1' : (share * 100).round().toString());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: empty ? AppColors.line : color,
                shape: BoxShape.circle,
              ),
              child: Icon(iconFor(icon), color: empty ? AppColors.muted.withValues(alpha: 0.5) : Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('$pct % • $count transaction${count > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            Text(
              money(cents),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: empty ? AppColors.muted.withValues(alpha: 0.45) : AppColors.ink,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Détail d'une catégorie principale : toutes ses sous-catégories, même à 0 €.
class ParentCategoryScreen extends StatefulWidget {
  final Category parent;
  final DateTime month;
  final bool expenses;
  const ParentCategoryScreen({super.key, required this.parent, required this.month, required this.expenses});

  @override
  State<ParentCategoryScreen> createState() => _ParentCategoryScreenState();
}

class _ParentCategoryScreenState extends State<ParentCategoryScreen> {
  late DateTime _month = widget.month;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final subs = store.subTotals(_month, widget.parent, expenses: widget.expenses);
        final total = subs.fold<int>(0, (s, c) => s + c.cents);
        final color = Color(widget.parent.color);
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.parent.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    MonthBar(month: _month, onChanged: (m) => setState(() => _month = m)),
                    Text(money(total),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: Column(
                  children: _divided([
                    for (final c in subs)
                      _AmountRow(
                        icon: c.category.icon,
                        color: color,
                        title: c.category.id == widget.parent.id ? '${c.category.name} (sans détail)' : c.category.name,
                        cents: c.cents,
                        count: c.count,
                        total: total,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => TxListScreen(
                            title: c.category.name,
                            month: _month,
                            expenses: widget.expenses,
                            where: (t) => t.categoryId == c.category.id,
                          ),
                        )),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Opérations d'un mois (filtrées), regroupées par jour avec le total du jour.
class TxListScreen extends StatelessWidget {
  final String title;
  final DateTime month;
  final bool expenses;
  final bool Function(Tx) where;
  const TxListScreen({super.key, required this.title, required this.month, required this.expenses, required this.where});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.monthFiltered(month, expenses: expenses, where: where);
        final days = <DateTime, List<Tx>>{};
        for (final t in list) {
          days.putIfAbsent(t.date, () => []).add(t);
        }
        final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
        return Scaffold(
          appBar: AppBar(
            title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          body: list.isEmpty
              ? EmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'Rien en ${monthTitle(month).toLowerCase()}',
                  message: 'Aucune opération dans cette catégorie ce mois-ci.',
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    for (final d in keys) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(dayTitle(d), style: const TextStyle(color: AppColors.ink, fontSize: 15))),
                            Text(
                              signedMoney(days[d]!.fold<int>(0, (s, t) => s + store.netCents(t))),
                              style: const TextStyle(color: AppColors.ink, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          children: [for (final t in days[d]!) TxTile(t, onTap: () => showTxSheet(context, t.id))],
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
