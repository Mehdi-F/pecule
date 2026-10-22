import 'package:flutter/material.dart';

import '../../format.dart';
import '../../store.dart';
import '../import_flow.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tx_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bal = store.currentBalance;
        final userRules = store.rules.where((r) => r.priority > 0).length;
        return Scaffold(
          appBar: AppBar(title: const Text('Réglages')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              const SectionTitle('DONNÉES'),
              _Group(children: [
                _Item(
                  icon: Icons.file_upload_outlined,
                  title: 'Importer un relevé',
                  subtitle: 'CSV ou OFX · ${store.txs.length} opérations en mémoire',
                  onTap: () => runImport(context),
                ),
                _Item(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Solde actuel',
                  subtitle: bal == null ? 'Non renseigné' : money(bal),
                  onTap: () => editBalance(context),
                ),
              ]),
              const SectionTitle('BUDGET & CATÉGORIES'),
              _Group(children: [
                _Item(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'Budget mensuel',
                  subtitle: store.budgetCents == null ? 'Non défini' : money(store.budgetCents!),
                  onTap: () => editBudget(context),
                ),
                _Item(
                  icon: Icons.category_outlined,
                  title: 'Nouvelle catégorie',
                  subtitle: '${store.categories.length} catégories',
                  onTap: () => createCategoryDialog(context),
                ),
                _Item(
                  icon: Icons.rule_rounded,
                  title: 'Règles de catégorisation',
                  subtitle: '$userRules perso · ${store.rules.length - userRules} par défaut',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RulesScreen())),
                ),
              ]),
              const SectionTitle('AIDE'),
              const AppCard(
                child: Text(
                  'Depuis le site LCL (sur ordinateur ou en version web), télécharge l\'historique de ton compte '
                  'au format CSV ou OFX, puis importe-le ici. Tu peux réimporter des périodes qui se chevauchent : '
                  'les doublons sont ignorés. Garde le même format d\'un import à l\'autre.\n\n'
                  'Pour lier un remboursement : ouvre une dépense (ou l\'entrée d\'argent), puis « Lier un remboursement ». '
                  'Les analyses et le budget comptent alors le montant net.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ),
              const SectionTitle('ZONE SENSIBLE'),
              _Group(children: [
                _Item(
                  icon: Icons.delete_forever_outlined,
                  title: 'Effacer toutes les opérations',
                  subtitle: 'Garde tes catégories, règles et budget',
                  danger: true,
                  onTap: () async {
                    final ok = await confirmDialog(context, 'Tout effacer ?',
                        'Les opérations et les remboursements liés seront supprimés de l\'app.',
                        ok: 'Effacer');
                    if (ok) await store.clearTransactions();
                  },
                ),
              ]),
              const SizedBox(height: 12),
              const Column(
                children: [
                  AppLogo(size: 48),
                  SizedBox(height: 8),
                  Text('Pécule', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                  Text('Tes données restent sur ce téléphone.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      );
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  const _Item({required this.icon, required this.title, required this.subtitle, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: danger ? AppColors.red : AppColors.primary),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? AppColors.red : AppColors.ink)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final rules = store.sortedRules;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Règles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: rules.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Une règle range automatiquement les opérations dont le libellé contient le mot-clé. '
                    'Tes règles perso passent avant celles par défaut. Supprimer une règle ne change pas les opérations déjà rangées.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                );
              }
              final r = rules[i - 1];
              final cat = store.categories[r.categoryId] ?? Store.unknownCategory;
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CategoryAvatar(cat, size: 36),
                  title: Text(r.keyword, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${cat.name}${r.priority > 0 ? ' · perso' : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => store.deleteRule(r),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
