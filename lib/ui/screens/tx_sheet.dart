import 'dart:math';

import 'package:flutter/material.dart';

import '../../format.dart';
import '../../models.dart';
import '../../store.dart';
import '../../text_utils.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> showTxSheet(BuildContext context, int txId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => TxSheet(txId: txId),
  );
}

class TxSheet extends StatefulWidget {
  final int txId;
  const TxSheet({super.key, required this.txId});

  @override
  State<TxSheet> createState() => _TxSheetState();
}

class _TxSheetState extends State<TxSheet> {
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: store.txById(widget.txId)?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _changeCategory(Tx t) async {
    final id = await pickCategory(context, selected: t.categoryId, forExpense: t.isExpense);
    if (id == null || !mounted || id == t.categoryId) return;
    await store.setCategory(t, id);
    if (!mounted) return;
    final keyword = await _askRule(t, store.categories[id]?.name ?? '');
    if (keyword == null || keyword.trim().isEmpty || !mounted) return;
    final n = await store.addRuleAndApply(keyword, id);
    if (!mounted) return;
    toast(context, n == 0 ? 'Règle créée pour les prochains imports.' : 'Règle créée, $n opération${n > 1 ? 's' : ''} mise${n > 1 ? 's' : ''} à jour.');
  }

  Future<void> _pickMonth(Tx t) async {
    final natural = DateTime(t.date.year, t.date.month);
    final options = [
      DateTime(natural.year, natural.month - 1),
      natural,
      DateTime(natural.year, natural.month + 1),
    ];
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(8, 16, 8, 16 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Compter cette opération en…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            for (final m in options)
              ListTile(
                title: Text(monthTitle(m)),
                subtitle: m == natural ? const Text('Mois de l\'opération') : null,
                trailing: m == t.analysisMonth ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await store.setMonthOverride(t, picked);
  }

  Future<String?> _askRule(Tx t, String catName) {
    final ctrl = TextEditingController(text: merchantKey(t.label));
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appliquer aux opérations similaires ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Les opérations dont le libellé contient ce mot-clé passeront en « $catName », y compris aux prochains imports.'),
            const SizedBox(height: 12),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Mot-clé')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Seulement celle-ci')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Appliquer')),
        ],
      ),
    );
  }

  Future<void> _delete(Tx t) async {
    final ok = await confirmDialog(context, 'Supprimer l\'opération ?',
        'Elle disparaîtra de l\'app (pas de ton compte). Un nouvel import du même fichier la réimportera.',
        ok: 'Supprimer');
    if (!ok || !mounted) return;
    Navigator.pop(context);
    await store.deleteTx(t);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = store.txById(widget.txId);
        if (t == null) return const SizedBox(height: 120);
        final cat = store.categoryOf(t);
        final reimb = t.isExpense ? store.reimbursed(t) : store.allocated(t);
        final txLinks = store.linksOf(t);
        // Feuille déplaçable : on la tire vers le haut pour l'agrandir ; rien sous la barre de navigation.
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.3,
          maxChildSize: 1,
          builder: (context, scroll) => SingleChildScrollView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted),
                    onPressed: () => _delete(t),
                  ),
                ),
                Center(child: CategoryAvatar(cat, size: 64)),
                const SizedBox(height: 12),
                Text(t.label, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(dayTitle(t.date), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                Text(
                  signedMoney(t.amountCents),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: t.isExpense ? AppColors.ink : AppColors.green,
                  ),
                ),
                if (reimb > 0)
                  Text(
                    t.isExpense
                        ? 'Net après remboursements : ${signedMoney(store.netCents(t))}'
                        : 'Compté dans les entrées : ${money(store.netCents(t))}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 24),
                const SectionTitle('CATÉGORIE'),
                _Box(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: CategoryAvatar(cat, size: 36),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: cat.parentId == null ? null : Text(store.topOf(cat).name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _changeCategory(t),
                  ),
                ),
                const SizedBox(height: 10),
                _Box(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                    title: const Text('Mois', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Mois dans lequel l\'opération compte pour l\'analyse'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(monthName(t.analysisMonth),
                            style: TextStyle(
                                color: t.monthOverride == null ? AppColors.muted : AppColors.primary,
                                fontWeight: FontWeight.w600)),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => _pickMonth(t),
                  ),
                ),
                const SizedBox(height: 10),
                _Box(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: const Text('Exclure des analyses'),
                    subtitle: const Text('Ex. virement entre tes propres comptes'),
                    value: t.excluded,
                    onChanged: (v) => store.setExcluded(t, v),
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(t.isExpense ? 'REMBOURSEMENTS' : 'REMBOURSE DES DÉPENSES'),
                _Box(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t.isExpense
                              ? 'Remboursé : ${money(reimb)} sur ${money(-t.amountCents)}'
                              : 'Affecté : ${money(reimb)} sur ${money(t.amountCents)}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        for (final l in txLinks) _LinkRow(link: l, fromExpense: t.isExpense),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: store.remaining(t) > 0
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => LinkPickerScreen(sourceId: t.id)),
                                  )
                              : null,
                          icon: const Icon(Icons.link_rounded),
                          label: Text(t.isExpense ? 'Lier un remboursement' : 'Lier à une dépense'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle('NOTE'),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  minLines: 1,
                  onChanged: (v) => store.setNote(t, v),
                  decoration: InputDecoration(
                    hintText: 'Ajouter une note…',
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Libellé bancaire : ${t.rawLabel}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  final Widget child;
  const _Box({required this.child});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _LinkRow extends StatelessWidget {
  final Link link;
  final bool fromExpense;
  const _LinkRow({required this.link, required this.fromExpense});

  @override
  Widget build(BuildContext context) {
    final other = store.txById(fromExpense ? link.incomeId : link.expenseId);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              other == null ? 'Opération supprimée' : '${other.label} · ${shortDate(other.date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(money(link.amountCents), style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Délier',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => store.removeLink(link),
          ),
        ],
      ),
    );
  }
}

/// Choix de l'opération de sens opposé à lier, puis du montant.
class LinkPickerScreen extends StatefulWidget {
  final int sourceId;
  const LinkPickerScreen({super.key, required this.sourceId});

  @override
  State<LinkPickerScreen> createState() => _LinkPickerScreenState();
}

class _LinkPickerScreenState extends State<LinkPickerScreen> {
  String _query = '';

  Future<void> _pick(Tx src, Tx other) async {
    final maxC = min(store.remaining(src), store.remaining(other));
    final cents = await showAmountDialog(
      context,
      title: src.isExpense ? 'Montant remboursé' : 'Montant affecté',
      initialCents: maxC,
      maxCents: maxC,
      helper: 'Tu peux ne lier qu\'une partie (ex. ta part d\'un resto).',
    );
    if (cents == null || !mounted) return;
    final expense = src.isExpense ? src : other;
    final income = src.isExpense ? other : src;
    await store.addLink(expense, income, cents);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final src = store.txById(widget.sourceId);
    if (src == null) return const Scaffold();
    final q = normalize(_query);
    final candidates = store.txs
        .where((c) =>
            c.id != src.id &&
            c.isExpense != src.isExpense &&
            store.remaining(c) > 0 &&
            (q.isEmpty || normalize('${c.label} ${c.rawLabel}').contains(q)))
        .toList()
      ..sort((a, b) => a.date.difference(src.date).inDays.abs().compareTo(b.date.difference(src.date).inDays.abs()));
    final shown = candidates.take(200).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(src.isExpense ? 'Choisir le remboursement' : 'Choisir la dépense',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Rechercher un libellé',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucune opération disponible',
                    message: src.isExpense
                        ? 'Il faut une entrée d\'argent pas encore entièrement affectée.'
                        : 'Il faut une dépense pas encore entièrement remboursée.',
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final c = shown[i];
                      return AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: TxTile(
                          c,
                          showDate: true,
                          onTap: () => _pick(src, c),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(signedMoney(c.amountCents), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('dispo ${money(store.remaining(c))}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de catégorie à deux niveaux, avec recherche. Renvoie l'id choisi.
Future<int?> pickCategory(BuildContext context, {int? selected, bool? forExpense}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _CategoryPicker(selected: selected, forExpense: forExpense),
  );
}

class _CategoryPicker extends StatefulWidget {
  final int? selected;
  final bool? forExpense;
  const _CategoryPicker({this.selected, this.forExpense});

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tops = store.topCategories();
    // Les catégories du bon sens (dépense / entrée) d'abord.
    final want = widget.forExpense == null ? null : (widget.forExpense! ? 'expense' : 'income');
    if (want != null) {
      tops.sort((a, b) {
        final pa = a.kind == want ? 0 : 1, pb = b.kind == want ? 0 : 1;
        return pa != pb ? pa.compareTo(pb) : a.sortOrder.compareTo(b.sortOrder);
      });
    }
    final selectedTop = widget.selected == null || store.categories[widget.selected] == null
        ? null
        : store.topOf(store.categories[widget.selected]!).id;
    final q = normalize(_query);

    Widget leaf(Category c, {bool showParent = false}) => ListTile(
          contentPadding: const EdgeInsets.only(left: 28, right: 16),
          leading: Icon(iconFor(c.icon), color: Color(c.color), size: 22),
          title: Text(c.name),
          subtitle: showParent && c.parentId != null ? Text(store.topOf(c).name) : null,
          trailing: c.id == widget.selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
          onTap: () => Navigator.pop(context, c.id),
        );

    final children = <Widget>[];
    if (q.isNotEmpty) {
      final matches = store.categories.values.where((c) => normalize(c.name).contains(q)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      children.addAll(matches.map((c) => leaf(c, showParent: true)));
      if (matches.isEmpty) {
        children.add(const Padding(padding: EdgeInsets.all(24), child: Text('Aucune catégorie trouvée.')));
      }
    } else {
      for (final top in tops) {
        final subs = store.childrenOf(top.id);
        if (subs.isEmpty) {
          children.add(ListTile(
            leading: CategoryAvatar(top, size: 40, filled: true),
            title: Text(top.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: top.id == widget.selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(context, top.id),
          ));
          continue;
        }
        children.add(Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: top.id == selectedTop,
            leading: CategoryAvatar(top, size: 40, filled: true),
            title: Text(top.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [for (final c in subs) leaf(c)],
          ),
        ));
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.35,
      maxChildSize: 1,
      builder: (context, scroll) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Catégories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Rechercher une catégorie',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          ListTile(
            title: const Text('Créer une catégorie'),
            trailing: const Icon(Icons.add_circle_outline_rounded),
            onTap: () async {
              final id = await createCategoryDialog(context);
              if (id != null && context.mounted) Navigator.pop(context, id);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Création d'une catégorie principale ou d'une sous-catégorie.
Future<int?> createCategoryDialog(BuildContext context) async {
  final name = TextEditingController();
  var icon = pickableIcons.first;
  var color = categoryColors.first;
  int? parentId;
  final tops = store.topCategories();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom')),
              const SizedBox(height: 12),
              DropdownButton<int?>(
                isExpanded: true,
                value: parentId,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Catégorie principale')),
                  for (final t in tops) DropdownMenuItem<int?>(value: t.id, child: Text('Dans « ${t.name} »')),
                ],
                onChanged: (v) => setSt(() => parentId = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final k in pickableIcons)
                    InkWell(
                      onTap: () => setSt(() => icon = k),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: icon == k ? Color(color).withValues(alpha: 0.2) : Colors.transparent,
                        ),
                        child: Icon(iconFor(k), color: icon == k ? Color(color) : AppColors.muted, size: 20),
                      ),
                    ),
                ],
              ),
              if (parentId == null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in categoryColors)
                      GestureDetector(
                        onTap: () => setSt(() => color = c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(color: c == color ? AppColors.ink : Colors.transparent, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
        ],
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return null;
  return store.addCategory(name.text.trim(), icon, color, parentId: parentId);
}
