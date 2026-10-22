import 'package:flutter/material.dart';

import '../../background.dart';
import '../../format.dart';
import '../../store.dart';
import '../import_flow.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bank_sync.dart';
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
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              const SectionTitle('DONNÉES'),
              _Group(children: [
                _Item(
                  icon: Icons.file_upload_outlined,
                  title: 'Importer un relevé',
                  subtitle: 'Relevé PDF LCL, CSV ou OFX · ${store.txs.length} opérations',
                  onTap: () => runImport(context),
                ),
                _Item(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Solde actuel',
                  subtitle: bal == null ? 'Non renseigné' : money(bal),
                  onTap: () => editBalance(context),
                ),
              ]),
              const SectionTitle('SYNCHRO BANCAIRE'),
              _Group(children: [
                _Item(
                  icon: Icons.sync_rounded,
                  title: 'Synchro avec ma banque',
                  subtitle: !store.hasBankApp
                      ? 'Non configurée · via Enable Banking'
                      : !store.bankConnected
                          ? 'Clé importée · banque à connecter'
                          : store.bankExpired
                              ? 'Accès expiré · à reconnecter'
                              : '${store.ebAspsp ?? 'Banque'} connectée',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BankSyncScreen())),
                ),
              ]),
              const SectionTitle('AUTOMATIQUE'),
              _Group(children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                  title: const Text('Solde chaque matin', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                  subtitle: Text(store.dailyNotif
                      ? 'Synchro + notification vers ${store.dailyNotifHour} h'
                      : 'Synchro automatique et notification de ton solde'),
                  value: store.dailyNotif,
                  onChanged: (on) => _toggleDaily(context, on),
                ),
                if (store.dailyNotif) ...[
                  _Item(
                    icon: Icons.schedule_rounded,
                    title: 'Heure de la notification',
                    subtitle: '${store.dailyNotifHour} h (Android peut la décaler de quelques minutes)',
                    onTap: () => _pickHour(context),
                  ),
                  _Item(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Tester maintenant',
                    subtitle: 'Synchronise et envoie la notification tout de suite',
                    onTap: () async {
                      await runMorningSync(force: true);
                      if (context.mounted) toast(context, 'Notification envoyée.');
                    },
                  ),
                ],
                SwitchListTile(
                  secondary: const Icon(Icons.work_outline_rounded, color: AppColors.primary),
                  title: const Text('Salaire de fin de mois', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                  subtitle: Text(store.salaryShift
                      ? 'Reçu à partir du ${store.salaryShiftDay} : compté dans le mois suivant'
                      : 'Compter le salaire reçu en fin de mois dans le mois suivant'),
                  value: store.salaryShift,
                  onChanged: (on) => store.setSalaryShift(on),
                ),
                if (store.salaryShift)
                  _Item(
                    icon: Icons.event_rounded,
                    title: 'À partir du…',
                    subtitle: 'Le ${store.salaryShiftDay} du mois',
                    onTap: () => _pickShiftDay(context),
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
                  'Le plus simple : télécharge tes relevés de compte PDF depuis l\'appli ou le site LCL '
                  '(Documents → Relevés de compte de dépôt) et importe-les ici, plusieurs à la fois si tu veux. '
                  'Le solde de fin de relevé est repris automatiquement. Les fichiers CSV et OFX sont aussi acceptés. '
                  'Réimporter une période déjà importée ne crée pas de doublons (garde le même format d\'un import à l\'autre).\n\n'
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

Future<void> _toggleDaily(BuildContext context, bool on) async {
  if (!on) {
    await store.setDailyNotif(false);
    await cancelMorning();
    return;
  }
  final granted = await requestNotificationPermission();
  if (!granted) {
    if (context.mounted) toast(context, 'Autorise les notifications de Pécule dans les réglages Android.');
    return;
  }
  await store.setDailyNotif(true);
  await scheduleMorning(store.dailyNotifHour);
  if (context.mounted && !store.bankConnected) {
    toast(context, 'Connecte ta banque (Synchro bancaire) pour un solde à jour chaque matin.');
  }
}

Future<void> _pickHour(BuildContext context) async {
  final h = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Heure de la notification'),
      children: [
        for (final h in [6, 7, 8, 9, 10, 12, 18, 20])
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, h), child: Text('$h h')),
      ],
    ),
  );
  if (h == null) return;
  await store.setDailyNotif(true, hour: h);
  await scheduleMorning(h);
}

Future<void> _pickShiftDay(BuildContext context) async {
  final d = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Salaire compté le mois suivant à partir du…'),
      children: [
        for (final d in [20, 22, 24, 25, 26, 27, 28])
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, d), child: Text('$d du mois')),
      ],
    ),
  );
  if (d != null) await store.setSalaryShift(true, day: d);
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
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
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
                  subtitle: Text('${cat.parentId == null ? cat.name : '${store.topOf(cat).name} › ${cat.name}'}${r.priority > 0 ? ' · perso' : ''}'),
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
