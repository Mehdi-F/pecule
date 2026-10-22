import 'package:flutter/material.dart';

import '../format.dart';
import '../importer.dart' show parseAmountCents;
import '../models.dart';
import '../store.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class CategoryAvatar extends StatelessWidget {
  final Category category;
  final double size;
  const CategoryAvatar(this.category, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final c = Color(category.color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(iconFor(category.icon), color: c, size: size * 0.5),
    );
  }
}

class AmountChip extends StatelessWidget {
  final int cents;
  const AmountChip(this.cents, {super.key});

  @override
  Widget build(BuildContext context) {
    final pos = cents > 0;
    final neutral = cents == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: neutral ? AppColors.line : (pos ? AppColors.greenBg : AppColors.redBg),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        signedMoney(cents),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: neutral ? AppColors.muted : (pos ? AppColors.green : AppColors.red),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.3)),
      );
}

/// Ligne d'opération réutilisée partout.
class TxTile extends StatelessWidget {
  final Tx tx;
  final VoidCallback? onTap;
  final bool showDate;
  final Widget? trailing;

  const TxTile(this.tx, {super.key, this.onTap, this.showDate = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cat = store.categoryOf(tx);
    final reimb = tx.isExpense ? store.reimbursed(tx) : store.allocated(tx);
    final subtitle = <String>[
      if (showDate) shortDate(tx.date),
      cat.name,
      if (tx.excluded) 'exclue',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            CategoryAvatar(cat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      signedMoney(tx.amountCents),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: tx.isExpense ? AppColors.ink : AppColors.green,
                      ),
                    ),
                    if (reimb > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          tx.isExpense ? 'net ${signedMoney(store.netCents(tx))}' : 'affecté ${money(reimb)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class PillToggle extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const PillToggle({super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: i == index ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Saisie d'un montant en euros. Renvoie des centimes, ou null si annulé.
Future<int?> showAmountDialog(
  BuildContext context, {
  required String title,
  int? initialCents,
  String? helper,
  bool allowNegativeOrZero = false,
  int? maxCents,
}) {
  final ctrl = TextEditingController(text: initialCents == null ? '' : centsToInput(initialCents));
  String? error;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(suffixText: '€', helperText: helper, errorText: error, helperMaxLines: 3),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = parseAmountCents(ctrl.text);
              final invalid = v == null ||
                  (!allowNegativeOrZero && v <= 0) ||
                  (maxCents != null && v > maxCents);
              if (invalid) {
                setSt(() => error = maxCents != null ? 'Montant invalide (max ${money(maxCents)})' : 'Montant invalide');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String message, {String ok = 'Confirmer'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
