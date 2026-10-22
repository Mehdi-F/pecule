import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../importer.dart';
import '../store.dart';
import 'widgets.dart';

Future<void> runImport(BuildContext context) async {
  final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  if (res == null || res.files.isEmpty) return;
  final f = res.files.first;
  List<int>? bytes = f.bytes;
  if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
  if (!context.mounted) return;
  if (bytes == null) {
    toast(context, 'Impossible de lire le fichier.');
    return;
  }
  try {
    final r = await store.importBytes(bytes);
    if (!context.mounted) return;
    final lines = <String>[
      '${r.added} nouvelle${r.added > 1 ? 's' : ''} opération${r.added > 1 ? 's' : ''} importée${r.added > 1 ? 's' : ''}.',
      if (r.duplicates > 0) '${r.duplicates} déjà présente${r.duplicates > 1 ? 's' : ''}, ignorée${r.duplicates > 1 ? 's' : ''}.',
      if (r.balanceUpdated) 'Solde du compte mis à jour depuis le fichier.',
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import ${r.format} terminé'),
        content: Text(lines.join('\n')),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (!context.mounted) return;
    if (store.anchorBalanceCents == null && store.txs.isNotEmpty) {
      await editBalance(context);
    }
  } on ImportException catch (e) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import impossible'),
        content: Text(e.message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}

Future<void> editBalance(BuildContext context) async {
  final v = await showAmountDialog(
    context,
    title: 'Solde actuel du compte',
    initialCents: store.currentBalance,
    helper: 'Le solde affiché par ta banque aujourd\'hui. Il sert à calculer l\'évolution jour par jour.',
    allowNegativeOrZero: true,
  );
  if (v == null) return;
  await store.setAnchor(v, DateTime.now());
}

Future<void> editBudget(BuildContext context) async {
  final v = await showAmountDialog(
    context,
    title: 'Budget mensuel',
    initialCents: store.budgetCents,
    helper: 'Plafond de sorties par mois (après remboursements).',
  );
  if (v == null) return;
  await store.setBudget(v);
}
