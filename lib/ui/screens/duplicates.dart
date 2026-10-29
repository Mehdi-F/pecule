import 'package:flutter/material.dart';

import '../../format.dart';
import '../../models.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Revue des doublons possibles : l'utilisateur garde ou supprime chaque paire.
class DuplicatesScreen extends StatelessWidget {
  const DuplicatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pairs = store.suspectedDuplicates();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Doublons possibles',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          body: pairs.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Aucun doublon',
                  message: 'Aucune opération ne semble comptée deux fois.',
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Même montant, même libellé, à deux jours d\'écart au plus. Si c\'est vraiment deux achats '
                        '(deux cafés le même jour, par exemple), choisis « Garder les deux ».',
                        style: TextStyle(color: AppColors.muted, height: 1.4),
                      ),
                    ),
                    for (final (a, b) in pairs) _PairCard(a: a, b: b),
                  ],
                ),
        );
      },
    );
  }
}

class _PairCard extends StatelessWidget {
  final Tx a;
  final Tx b;
  const _PairCard({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TxTile(a, showDate: true),
          TxTile(b, showDate: true),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => store.ignoreDuplicate(a, b),
                  child: const Text('Garder les deux'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await store.resolveDuplicate(a, b);
                    if (context.mounted) toast(context, 'Doublon supprimé (${money(a.amountCents.abs())}).');
                  },
                  child: const Text('Supprimer le doublon'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
