import 'package:flutter/material.dart';

import '../../format.dart';
import '../../store.dart';
import '../import_flow.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bank_sync.dart';
import 'tx_sheet.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final days = store.days();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Activités'),
            actions: [
              if (store.bankConnected && !store.bankExpired)
                IconButton(
                  tooltip: 'Synchroniser',
                  icon: store.syncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded),
                  onPressed: store.syncing ? null : () => runBankSync(context),
                ),
              IconButton(
                tooltip: 'Importer un relevé',
                icon: const Icon(Icons.file_upload_outlined),
                onPressed: () => runImport(context),
              ),
            ],
          ),
          body: days.isEmpty
              ? EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  leading: const AppLogo(size: 96),
                  title: 'Bienvenue dans Pécule',
                  message: 'Importe tes relevés de compte PDF LCL (ou un CSV / OFX) pour commencer.',
                  action: FilledButton.icon(
                    onPressed: () => runImport(context),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Importer un relevé'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    if (store.bankConnected && !store.bankExpired) await runBankSync(context);
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
                    itemCount: days.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _BalanceCard();
                      return _DayCard(key: ValueKey(days[i - 1].day), day: days[i - 1]);
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final bal = store.currentBalance;
    return AppCard(
      onTap: () => editBalance(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Solde du compte', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                  bal == null ? 'Non renseigné' : money(bal),
                  style: TextStyle(
                    fontSize: bal == null ? 18 : 28,
                    fontWeight: FontWeight.w800,
                    color: bal != null && bal < 0 ? AppColors.red : AppColors.ink,
                  ),
                ),
                if (store.ebLastSync != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      store.bankExpired ? 'Accès bancaire expiré · à reconnecter' : 'Synchronisé ${syncAgo(store.ebLastSync!)}',
                      style: TextStyle(color: store.bankExpired ? AppColors.red : AppColors.muted, fontSize: 12),
                    ),
                  ),
                if (bal == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Touche pour saisir ton solde actuel et suivre son évolution.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _DayCard extends StatefulWidget {
  final DaySummary day;
  const _DayCard({super.key, required this.day});

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final n = d.txs.length;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                Expanded(child: Text(dayTitle(d.day), style: const TextStyle(color: AppColors.muted))),
                const Text('Évolution de compte', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$n opération${n > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(_open ? 'Masquer le détail' : 'Voir le détail',
                              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 18, color: AppColors.muted),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (d.balanceCents != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(money(d.balanceCents!),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      ),
                    AmountChip(d.deltaCents),
                  ],
                ),
              ],
            ),
          ),
          if (_open) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Column(
                children: [for (final t in d.txs) TxTile(t, onTap: () => showTxSheet(context, t.id))],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
