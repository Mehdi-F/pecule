import 'dart:convert';

import 'package:budget_app/categorizer.dart';
import 'package:budget_app/importer.dart';
import 'package:budget_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> b(String s) => utf8.encode(s);

void main() {
  test('montants', () {
    expect(parseAmountCents('-131,32'), -13132);
    expect(parseAmountCents('1 234,56'), 123456);
    expect(parseAmountCents('1 234,56 €'), 123456);
    expect(parseAmountCents('1.234,56'), 123456);
    expect(parseAmountCents('1,234.56'), 123456);
    expect(parseAmountCents('47.00'), 4700);
    expect(parseAmountCents('+47'), 4700);
    expect(parseAmountCents('12,5'), 1250);
    expect(parseAmountCents('abc'), isNull);
    expect(parseAmountCents(''), isNull);
    expect(parseAmountCents('22/10/2026'), isNull);
  });

  test('dates', () {
    expect(parseDate('22/10/2026'), DateTime(2026, 10, 22));
    expect(parseDate('22/10/26'), DateTime(2026, 10, 22));
    expect(parseDate('2026-10-22'), DateTime(2026, 10, 22));
    expect(parseDate('31/02/2026'), isNull);
  });

  test('CSV sans en-tête (style LCL)', () {
    const csv = '22/10/2026;-131,32;Carte;;CB  CARREFOUR MARKET 21/10;\n'
        '22/10/2026;47,00;Virement;;VIR SEPA RECU LYDIA;\n'
        '21/10/2026;-9,99;Prélèvement;;PRLV SEPA NETFLIX.COM;\n';
    final r = parseStatement(b(csv));
    expect(r.txs.length, 3);
    expect(r.txs[0].amountCents, -13132);
    expect(r.txs[0].date, DateTime(2026, 10, 22));
    expect(r.txs[0].label, 'Carrefour Market');
    expect(r.txs[1].amountCents, 4700);
    expect(r.txs[2].label, 'Netflix.com');
  });

  test('CSV latin-1 avec en-tête débit/crédit', () {
    const csv = 'Compte courant\nDate;Libellé;Débit;Crédit\n22/10/2026;CB CARREFOUR;131,32;\n22/10/2026;VIR SALAIRE;;1500,00\n';
    final r = parseStatement(latin1.encode(csv));
    expect(r.txs.map((t) => t.amountCents).toList(), [-13132, 150000]);
  });

  test('CSV avec en-tête montant et date de valeur', () {
    const csv = 'Date opération;Date valeur;Libellé;Montant;Solde\n2026-10-22;2026-10-23;PRLV FREE MOBILE;-19,99;250,00\n';
    final r = parseStatement(b(csv));
    expect(r.txs.single.date, DateTime(2026, 10, 22));
    expect(r.txs.single.amountCents, -1999);
  });

  test('hash stables et doublons dans un même fichier conservés', () {
    const csv = '01/10/2026;-2,50;CB BOULANGERIE\n01/10/2026;-2,50;CB BOULANGERIE\n';
    final a = parseStatement(b(csv));
    final again = parseStatement(b(csv));
    expect(a.txs.length, 2);
    expect(a.txs[0].hash == a.txs[1].hash, isFalse);
    expect(a.txs.map((t) => t.hash).toList(), again.txs.map((t) => t.hash).toList());
  });

  test('OFX avec solde', () {
    const ofx = 'OFXHEADER:100\n<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>\n'
        '<STMTTRN>\n<TRNTYPE>DEBIT\n<DTPOSTED>20261022\n<TRNAMT>-131.32\n<FITID>ABC1\n<NAME>CB CARREFOUR\n</STMTTRN>\n'
        '<STMTTRN>\n<TRNTYPE>CREDIT\n<DTPOSTED>20261021120000\n<TRNAMT>47.00\n<FITID>ABC2\n<NAME>VIR LYDIA\n<MEMO>Resto\n</STMTTRN>\n'
        '</BANKTRANLIST>\n<LEDGERBAL><BALAMT>267.72<DTASOF>20261022</LEDGERBAL>\n';
    final r = parseStatement(b(ofx));
    expect(r.format, 'OFX');
    expect(r.txs.length, 2);
    expect(r.txs[1].date, DateTime(2026, 10, 21));
    expect(r.txs[1].rawLabel, 'VIR LYDIA Resto');
    expect(r.balanceCents, 26772);
    expect(r.balanceDate, DateTime(2026, 10, 22));
  });

  test('fichier illisible', () {
    expect(() => parseStatement(b('bonjour\nceci n est pas un releve\n')), throwsA(isA<ImportException>()));
  });

  test('catégorisation par défaut (sous-catégories, sens de l\'opération)', () {
    final names = <String>[];
    final kinds = <String>[];
    for (final p in taxonomy) {
      names.add(p.name);
      kinds.add(p.kind);
      for (final sub in p.subs) {
        names.add(sub.name);
        kinds.add(p.kind);
      }
    }
    var id = 0;
    final rules = sortRules([
      for (final s in defaultRuleSeeds)
        Rule(id: id++, keyword: s.keyword, categoryId: names.indexOf(s.category), priority: s.priority),
    ]);
    String? cat(String label, {bool expense = true}) {
      final i = categorize(label, rules, isExpense: expense, kindOf: (c) => kinds[c]);
      return i == null ? null : names[i];
    }

    expect(cat('VIREMENT CPAM 123', expense: false), 'Remboursements');
    expect(cat('PRLV SEPA FREE MOBILE'), 'Internet & téléphonie');
    expect(cat('CB AMAZON PRIME'), 'Streaming & TV');
    expect(cat('CB AMAZON MKTP FR'), 'Achats & Shopping - Autres');
    expect(cat('VIR SEPA RECU SALAIRE OCTOBRE', expense: false), 'Salaires');
    expect(cat('CB UBER *EATS'), 'Sortie au restaurant');
    expect(cat('CB UBER TRIP'), 'Taxi / VTC');
    expect(cat('VIR SEPA EMIS M DUPONT'), 'Virements émis');
    expect(cat('VIR INST M DUPONT', expense: false), 'Virements reçus');
    expect(cat('VIR.PERMANENT LA RHONELLE IMMOB'), 'Loyer');
    expect(cat('PRLV SEPA TotalEnergies Electricite et Gaz France'), 'Électricité');
    expect(cat('CB Revolut**8072*'), 'Virements épargne');
    expect(cat('MUTUELLE ABC', expense: false), 'Remboursements');
    expect(cat('MUTUELLE ABC'), 'Mutuelle');
    expect(cat('CB VIRGIN MEGASTORE'), isNull);
  });

  test('taxonomie : noms uniques', () {
    final names = [for (final p in taxonomy) ...[p.name, ...p.subs.map((s) => s.name)]];
    expect(names.toSet().length, names.length);
    for (final r in defaultRuleSeeds) {
      expect(names.contains(r.category), isTrue, reason: r.category);
    }
  });
}
