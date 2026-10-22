import 'package:budget_app/bank/eb_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction débit comptabilisée', () {
    final t = mapEbTransaction({
      'entry_reference': 'ABC123',
      'transaction_amount': {'amount': '24.90', 'currency': 'EUR'},
      'credit_debit_indicator': 'DBIT',
      'status': 'BOOK',
      'booking_date': '2026-10-21',
      'remittance_information': ['CB SUSHI 8 20/10/26'],
      'creditor': {'name': 'SUSHI 8'},
    }, {})!;
    expect(t.amountCents, -2490);
    expect(t.date, DateTime(2026, 10, 21));
    expect(t.label, 'Sushi 8');
    expect(t.hash, 'eb|ABC123');
  });

  test('crédit sans référence : empreinte stable préfixée', () {
    Map<String, dynamic> j() => {
          'transaction_amount': {'amount': '2109.54', 'currency': 'EUR'},
          'credit_debit_indicator': 'CRDT',
          'status': 'BOOK',
          'value_date': '2026-09-29',
          'remittance_information': ['VIREMENT EMPLOYEUR', 'SALARY 09-2026'],
          'debtor': {'name': 'EMPLOYEUR SAS'},
        };
    final a = mapEbTransaction(j(), {})!;
    final b = mapEbTransaction(j(), {})!;
    expect(a.amountCents, 210954);
    expect(a.hash, startsWith(bankHashPrefix));
    expect(a.hash, b.hash);
    expect(a.rawLabel, contains('SALARY'));
    expect(a.rawLabel, contains('EMPLOYEUR SAS'));
  });

  test('opération en attente ignorée', () {
    expect(
      mapEbTransaction({
        'transaction_amount': {'amount': '5.00'},
        'credit_debit_indicator': 'DBIT',
        'status': 'PDNG',
        'booking_date': '2026-10-22',
      }, {}),
      isNull,
    );
  });

  test('solde : le comptabilisé est préféré', () {
    final b = pickBalance([
      {'balance_type': 'XPCD', 'balance_amount': {'amount': '100.00'}, 'reference_date': '2026-10-22'},
      {'balance_type': 'CLBD', 'balance_amount': {'amount': '-12.50'}, 'reference_date': '2026-10-21'},
    ])!;
    expect(b.$1, -1250);
    expect(b.$2, DateTime(2026, 10, 21));
    expect(pickBalance(const []), isNull);
  });
}
