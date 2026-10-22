import 'package:budget_app/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('libellés nettoyés', () {
    expect(cleanLabel('CB  CARREFOUR MARKET 21/10'), 'Carrefour Market');
    expect(cleanLabel('PRLV SEPA FREE MOBILE'), 'Free Mobile');
    expect(cleanLabel('VIR SEPA RECU LYDIA'), 'Lydia');
    expect(cleanLabel('VIRGIN MOBILE'), 'Virgin Mobile');
    expect(cleanLabel('RETRAIT DAB'), 'Retrait Dab');
    expect(
        cleanLabel('PRELVT SEPA RECU D/O CONFRERE PRLV SEPA WORKLIFE ICS.NL48ZZZ342764500000 .RUM.S2GGQTZFCF2KBVQ9 SDR629392497866'),
        'Worklife');
    expect(cleanLabel('Prelvt Sepa Recu D/o Confrere Prlv Sepa Worklife Ics.nl48zzz342764500000 .rum.s2ggqtzfcf2kbvq9 Sdr629392497866'),
        'Worklife');
    expect(cleanLabel('CB SUSHI 8 20/10/26'), 'Sushi 8');
  });

  test('mot-clé marchand', () {
    expect(merchantKey('CB CARREFOUR MARKET 21/10'), 'CARREFOUR MARKET');
    expect(merchantKey('Netflix.com'), 'NETFLIX.COM');
  });

  test('normalisation', () {
    expect(normalize('Prélèvement  Santé'), 'PRELEVEMENT SANTE');
  });
}
