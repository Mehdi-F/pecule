import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../importer.dart';
import '../store.dart';
import 'widgets.dart';

String _plural(int n, String word) => '$n $word${n > 1 ? 's' : ''}';

/// Import d'un ou plusieurs fichiers (relevés PDF LCL, CSV ou OFX).
Future<void> runImport(BuildContext context) async {
  final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true, allowMultiple: true);
  if (res == null || res.files.isEmpty || !context.mounted) return;

  var added = 0, duplicates = 0;
  var balanceUpdated = false;
  final errors = <String>[];

  // Petit indicateur pendant la lecture (un relevé PDF peut prendre une seconde).
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  for (final f in res.files) {
    try {
      List<int>? bytes = f.bytes;
      if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
      if (bytes == null) throw const ImportException('fichier illisible');
      final r = await store.importBytes(bytes);
      added += r.added;
      duplicates += r.duplicates;
      balanceUpdated |= r.balanceUpdated;
    } on ImportException catch (e) {
      errors.add('${f.name} : ${e.message}');
    } catch (e) {
      errors.add('${f.name} : erreur inattendue ($e)');
    }
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  final ok = res.files.length - errors.length;
  final lines = <String>[
    if (ok > 0) '${_plural(added, 'nouvelle opération')} importée${added > 1 ? 's' : ''}.',
    if (duplicates > 0) '${_plural(duplicates, 'opération')} déjà présente${duplicates > 1 ? 's' : ''}, ignorée${duplicates > 1 ? 's' : ''}.',
    if (balanceUpdated) 'Solde du compte mis à jour depuis le relevé.',
    if (errors.isNotEmpty) ...['', ...errors],
  ];
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(errors.isEmpty ? 'Import terminé' : (ok > 0 ? 'Import partiel' : 'Import impossible')),
      content: SingleChildScrollView(child: Text(lines.join('\n'))),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
  if (!context.mounted) return;
  if (store.anchorBalanceCents == null && store.txs.isNotEmpty) {
    await editBalance(context);
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
