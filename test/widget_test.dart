import 'package:budget_app/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('libellés nettoyés', () {
    expect(cleanLabel('CB  CARREFOUR MARKET 21/10'), 'Carrefour Market');
    expect(cleanLabel('PRLV SEPA FREE MOBILE'), 'Free Mobile');
    expect(cleanLabel('VIR SEPA RECU LYDIA'), 'Lydia');
    expect(cleanLabel('VIRGIN MOBILE'), 'Virgin Mobile');
    expect(cleanLabel('RETRAIT DAB'), 'Retrait Dab');
  });

  test('mot-clé marchand', () {
    expect(merchantKey('CB CARREFOUR MARKET 21/10'), 'CARREFOUR MARKET');
    expect(merchantKey('Netflix.com'), 'NETFLIX.COM');
  });

  test('normalisation', () {
    expect(normalize('Prélèvement  Santé'), 'PRELEVEMENT SANTE');
  });
}
