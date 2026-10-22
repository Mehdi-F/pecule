import 'dart:io';

import 'package:budget_app/lcl_pdf.dart';
import 'package:budget_app/pdf_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relevé PDF LCL (fictif) : opérations, années, libellés et solde', () {
    final bytes = File('test/fixtures/releve_lcl_fictif.pdf').readAsBytesSync();
    expect(isPdf(bytes), isTrue);
    final r = parseLclPdfBytes(bytes);

    expect(r.format, 'PDF');
    expect(r.txs.length, 7);
    expect(r.balanceCents, 164478);
    expect(r.balanceDate, DateTime(2026, 1, 31));

    final debits = r.txs.where((t) => t.amountCents < 0).fold<int>(0, (s, t) => s - t.amountCents);
    final credits = r.txs.where((t) => t.amountCents > 0).fold<int>(0, (s, t) => s + t.amountCents);
    expect(debits, 150766);
    expect(credits, 215244);

    final first = r.txs.first;
    expect(first.date, DateTime(2025, 12, 15)); // décembre du relevé qui finit en janvier
    expect(first.amountCents, -4250);
    expect(first.label, 'Carrefour Market');

    final perm = r.txs[1];
    expect(perm.label, 'Jean Revolut');
    expect(perm.rawLabel, contains('Virement permanent'));

    final cpam = r.txs[2];
    expect(cpam.amountCents, 1230);
    expect(cpam.rawLabel, isNot(contains('REF.CLIENT')));

    final impot = r.txs[3];
    expect(impot.amountCents, -123456);
    expect(impot.label, endsWith('Publiques'));
    expect(impot.rawLabel, isNot(contains('CREANCIER')));

    final salary = r.txs.last;
    expect(salary.amountCents, 210954);
    expect(salary.rawLabel, contains('SALARY'));
  });

  test('mots positionnés : débit / crédit selon la colonne', () {
    const words = [
      PdfWord(0, 100, 41, 66, 'DATE'),
      PdfWord(0, 100, 197, 234, 'LIBELLE'),
      PdfWord(0, 100, 365, 402, 'VALEUR'),
      PdfWord(0, 100, 433, 460, 'DEBIT'),
      PdfWord(0, 100, 504, 538, 'CREDIT'),
      PdfWord(0, 120, 42, 65, '02.03'),
      PdfWord(0, 120.6, 75, 86, 'CB'),
      PdfWord(0, 120.6, 88, 120, 'KFC'),
      PdfWord(0, 120, 366, 401, '02.03.26'),
      PdfWord(0, 120, 458, 481, '10,95'),
      PdfWord(0, 132, 42, 65, '03.03'),
      PdfWord(0, 132.6, 75, 120, 'VIREMENT'),
      PdfWord(0, 132.6, 122, 150, 'AMI'),
      PdfWord(0, 132, 366, 401, '03.03.26'),
      PdfWord(0, 132, 541, 559, '5,00'),
    ];
    final r = parseLclPdf(words);
    expect(r.txs.map((t) => t.amountCents).toList(), [-1095, 500]);
  });

  test('PDF sans tableau LCL refusé', () {
    expect(() => parseLclPdf(const [PdfWord(0, 10, 10, 50, 'Bonjour')]), throwsA(anything));
  });
}
