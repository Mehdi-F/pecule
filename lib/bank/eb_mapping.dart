import '../importer.dart';
import '../text_utils.dart';

/// Préfixe des empreintes des opérations venues de la synchro bancaire.
const String bankHashPrefix = 'eb|';

String? _str(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

String? _name(Object? party) => party is Map ? _str(party['name']) : null;

/// Convertit une transaction Enable Banking en opération Pécule.
/// Les opérations en attente (non comptabilisées) sont ignorées.
ParsedTx? mapEbTransaction(Map<String, dynamic> j, Map<String, int> occ) {
  final status = _str(j['status']);
  if (status != null && status != 'BOOK') return null;

  final amount = j['transaction_amount'];
  final raw = amount is Map ? _str(amount['amount']) : null;
  var cents = parseAmountCents(raw ?? '');
  if (cents == null || cents == 0) return null;
  final debit = _str(j['credit_debit_indicator']) == 'DBIT' || (raw ?? '').startsWith('-');
  cents = debit ? -cents.abs() : cents.abs();

  final dateStr = _str(j['booking_date']) ?? _str(j['value_date']) ?? _str(j['transaction_date']);
  final parsedDate = dateStr == null ? null : DateTime.tryParse(dateStr);
  if (parsedDate == null) return null;
  final date = dateOnly(parsedDate);

  final remittance = <String>[
    if (j['remittance_information'] is List)
      for (final r in j['remittance_information'] as List)
        if (_str(r) != null) _str(r)!,
  ];
  final counterparty = debit ? _name(j['creditor']) : _name(j['debtor']);
  final code = j['bank_transaction_code'];
  final codeDesc = code is Map ? _str(code['description']) : null;

  final main = remittance.isNotEmpty ? remittance.first : (counterparty ?? codeDesc ?? 'Opération');
  final parts = <String>[];
  for (final p in [main, ...remittance.skip(1).take(2), counterparty]) {
    if (p != null && !parts.contains(p)) parts.add(p);
  }
  final rawLabel = parts.join(' ');

  final ref = _str(j['entry_reference']) ?? _str(j['transaction_id']);
  final p = makeParsedTx(date, cents, main, rawLabel, occ, hashLabel: main);
  final hash = ref != null ? '$bankHashPrefix$ref' : '$bankHashPrefix${p.hash}';
  return ParsedTx(p.date, p.amountCents, p.label, p.rawLabel, hash);
}

/// Solde le plus fiable parmi ceux renvoyés par la banque (comptabilisé en priorité).
(int, DateTime)? pickBalance(List<dynamic> balances) {
  const order = ['CLBD', 'ITBD', 'XPCD', 'CLAV', 'ITAV', 'OPBD', 'OTHR'];
  Map<String, dynamic>? best;
  var bestRank = 999;
  for (final b in balances) {
    if (b is! Map<String, dynamic>) continue;
    final type = _str(b['balance_type']) ?? 'OTHR';
    final rank = order.contains(type) ? order.indexOf(type) : order.length;
    if (rank < bestRank) {
      bestRank = rank;
      best = b;
    }
  }
  if (best == null) return null;
  final amount = best['balance_amount'];
  final cents = parseAmountCents(amount is Map ? (_str(amount['amount']) ?? '') : '');
  if (cents == null) return null;
  final ref = _str(best['reference_date']) ?? _str(best['last_change_date_time']);
  final date = ref == null ? null : DateTime.tryParse(ref);
  return (cents, dateOnly(date ?? DateTime.now()));
}
